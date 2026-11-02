#include "transport/websocket_transport.h"

#include <ixwebsocket/IXConnectionState.h>
#include <ixwebsocket/IXWebSocket.h>
#include <ixwebsocket/IXWebSocketServer.h>

namespace rmm {

namespace {

// Per-connection state carrying our client id.
class ClientState : public ix::ConnectionState {
 public:
  ClientId client = 0;
};

}  // namespace

WebSocketTransport::WebSocketTransport(std::string host, int port)
    : server_(std::make_unique<ix::WebSocketServer>(port, host)) {
  server_->disablePerMessageDeflate();
  server_->setConnectionStateFactory([] { return std::make_shared<ClientState>(); });
  server_->setOnClientMessageCallback([this](std::shared_ptr<ix::ConnectionState> state,
                                             ix::WebSocket& socket,
                                             const ix::WebSocketMessagePtr& msg) {
    auto& clientState = static_cast<ClientState&>(*state);
    switch (msg->type) {
      case ix::WebSocketMessageType::Open: {
        {
          std::lock_guard lock(connectionsMutex_);
          clientState.client = nextClientId_++;
          connections_[clientState.client] = &socket;
        }
        pushEvent({Event::Kind::Connected, clientState.client, {}});
        break;
      }
      case ix::WebSocketMessageType::Message:
        if (!msg->binary) pushEvent({Event::Kind::Message, clientState.client, msg->str});
        break;
      case ix::WebSocketMessageType::Close: {
        {
          std::lock_guard lock(connectionsMutex_);
          connections_.erase(clientState.client);
        }
        pushEvent({Event::Kind::Disconnected, clientState.client, {}});
        break;
      }
      default:
        break;
    }
  });
}

WebSocketTransport::~WebSocketTransport() { stop(); }

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
    std::lock_guard lock(connectionsMutex_);
    const auto it = connections_.find(message.client);
    if (it != connections_.end()) it->second->sendText(message.text);
  }
}

}  // namespace rmm
