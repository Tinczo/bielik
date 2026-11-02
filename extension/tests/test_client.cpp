#include "test_client.h"

#include <atomic>
#include <thread>

#include <ixwebsocket/IXWebSocket.h>

namespace rmm::testing {

int nextTestPort() {
  static std::atomic<int> port{18790};
  return port++;
}

TestClient::TestClient(int port) : socket_(std::make_unique<ix::WebSocket>()) {
  socket_->setUrl("ws://127.0.0.1:" + std::to_string(port) + "/");
  socket_->disableAutomaticReconnection();
  socket_->setOnMessageCallback([this](const ix::WebSocketMessagePtr& msg) {
    std::lock_guard lock(mutex_);
    switch (msg->type) {
      case ix::WebSocketMessageType::Open:
        open_ = true;
        break;
      case ix::WebSocketMessageType::Close:
      case ix::WebSocketMessageType::Error:
        open_ = false;
        break;
      case ix::WebSocketMessageType::Message:
        messages_.push_back(msg->str);
        break;
      default:
        break;
    }
    changed_.notify_all();
  });
  socket_->start();

  std::unique_lock lock(mutex_);
  changed_.wait_for(lock, std::chrono::seconds(2), [this] { return open_; });
}

TestClient::~TestClient() { socket_->stop(); }

bool TestClient::isOpen() const {
  std::lock_guard lock(mutex_);
  return open_;
}

void TestClient::send(const std::string& text) { socket_->sendText(text); }

std::optional<std::string> TestClient::nextMessage(MixerServer& server,
                                                   std::chrono::milliseconds timeout) {
  return nextMessage([&server] { server.pump(); }, timeout);
}

bool TestClient::waitClosed(MixerServer& server, std::chrono::milliseconds timeout) {
  return waitClosed([&server] { server.pump(); }, timeout);
}

bool TestClient::waitClosed(const std::function<void()>& pump, std::chrono::milliseconds timeout) {
  const auto deadline = std::chrono::steady_clock::now() + timeout;
  while (std::chrono::steady_clock::now() < deadline) {
    pump();
    std::unique_lock lock(mutex_);
    if (changed_.wait_for(lock, std::chrono::milliseconds(5), [this] { return !open_; })) return true;
  }
  return false;
}

std::optional<std::string> TestClient::nextMessage(const std::function<void()>& pump,
                                                   std::chrono::milliseconds timeout) {
  const auto deadline = std::chrono::steady_clock::now() + timeout;
  while (std::chrono::steady_clock::now() < deadline) {
    pump();
    std::unique_lock lock(mutex_);
    if (changed_.wait_for(lock, std::chrono::milliseconds(5), [this] { return !messages_.empty(); })) {
      std::string message = std::move(messages_.front());
      messages_.pop_front();
      return message;
    }
  }
  return std::nullopt;
}

}  // namespace rmm::testing
