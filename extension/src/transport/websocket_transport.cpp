#include "transport/websocket_transport.h"

#include <ixwebsocket/IXConnectionState.h>
#include <ixwebsocket/IXWebSocket.h>
#include <ixwebsocket/IXWebSocketServer.h>

namespace rmm {

// Per-connection state carrying our client id.
class WebSocketTransport::ClientState : public ix::ConnectionState {
 public:
  ClientId client = 0;
};

WebSocketTransport::WebSocketTransport(std::string host, int port)
    : server_(std::make_unique<ix::WebSocketServer>(port, host)) {
  server_->disablePerMessageDeflate();
  server_->setConnectionStateFactory([] { return std::make_shared<ClientState>(); });
  server_->setOnConnectionCallback([this](std::weak_ptr<ix::WebSocket> socket,
                                          std::shared_ptr<ix::ConnectionState> state) {
    if (const auto opened = socket.lock()) {
      opened->setOnMessageCallback([this, socket, state](const ix::WebSocketMessagePtr& msg) {
        onMessage(socket, static_cast<ClientState&>(*state), msg);
      });
    }
  });
}

WebSocketTransport::~WebSocketTransport() { stop(); }

void WebSocketTransport::onMessage(const std::weak_ptr<ix::WebSocket>& socket, ClientState& state,
                                   const ix::WebSocketMessagePtr& msg) {
  switch (msg->type) {
    case ix::WebSocketMessageType::Open: {
      {
        std::lock_guard lock(connectionsMutex_);
        state.client = nextClientId_++;
        connections_[state.client] = socket;
      }
      pushEvent({Event::Kind::Connected, state.client, {}});
      break;
    }
    case ix::WebSocketMessageType::Message:
      if (!msg->binary) pushEvent({Event::Kind::Message, state.client, msg->str});
      break;
    case ix::WebSocketMessageType::Close: {
      {
        std::lock_guard lock(connectionsMutex_);
        connections_.erase(state.client);
      }
      pushEvent({Event::Kind::Disconnected, state.client, {}});
      break;
    }
    default:
      break;
  }
}

bool WebSocketTransport::start(std::string* error) {
  const auto [ok, reason] = server_->listen();
  if (!ok) {
    if (error) *error = reason;
    return false;
  }
  server_->start();
  {
    std::lock_guard lock(outboxMutex_);
    stopping_ = false;
  }
  sender_ = std::thread([this] { senderLoop(); });
  return true;
}

void WebSocketTransport::stop() {
  if (!sender_.joinable()) return;
  server_->stop();  // closes connections; their Close events still reach the inbox
  {
    std::lock_guard lock(outboxMutex_);
    stopping_ = true;
    outbox_.clear();
  }
  outboxReady_.notify_all();
  sender_.join();
}

std::vector<WebSocketTransport::Event> WebSocketTransport::takeEvents() {
  std::lock_guard lock(inboxMutex_);
  std::vector<Event> events;
  events.swap(inbox_);
  return events;
}

void WebSocketTransport::send(ClientId client, std::string text) {
  {
    std::lock_guard lock(outboxMutex_);
    outbox_.push_back({client, std::move(text)});
  }
  outboxReady_.notify_one();
}

void WebSocketTransport::close(ClientId client) {
  {
    std::lock_guard lock(outboxMutex_);
    outbox_.push_back({client, {}, true});
  }
  outboxReady_.notify_one();
}

void WebSocketTransport::pushEvent(Event event) {
  std::lock_guard lock(inboxMutex_);
  inbox_.push_back(std::move(event));
}

void WebSocketTransport::senderLoop() {
  for (;;) {
    Outgoing message;
    {
      std::unique_lock lock(outboxMutex_);
      outboxReady_.wait(lock, [this] { return stopping_ || !outbox_.empty(); });
      if (stopping_) return;
      message = std::move(outbox_.front());
      outbox_.pop_front();
    }
    // IXWebSocket holds its own lock while it calls onMessage(), which takes
    // connectionsMutex_, so never call into it with connectionsMutex_ held: a client leaving
    // during a send would deadlock, and stop() would then wait forever.
    std::shared_ptr<ix::WebSocket> socket;
    {
      std::lock_guard lock(connectionsMutex_);
      const auto it = connections_.find(message.client);
      if (it != connections_.end()) socket = it->second.lock();
    }
    if (!socket) continue;
    if (message.close) {
      socket->close();
    } else {
      socket->sendText(message.text);
    }
  }
}

}  // namespace rmm
