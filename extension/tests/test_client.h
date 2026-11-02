#pragma once

#include <chrono>
#include <condition_variable>
#include <deque>
#include <memory>
#include <mutex>
#include <optional>
#include <string>

#include "transport/mixer_server.h"

namespace ix {
class WebSocket;
}

namespace rmm::testing {

// Each test server gets its own port so a slow socket close cannot affect the next test.
int nextTestPort();

// A real WebSocket client connected to a MixerServer on localhost.
class TestClient {
 public:
  explicit TestClient(int port);
  ~TestClient();

  bool isOpen() const;
  void send(const std::string& text);

  // Waits for the next message, pumping the server's main-thread timer meanwhile.
  std::optional<std::string> nextMessage(MixerServer& server,
                                         std::chrono::milliseconds timeout = std::chrono::seconds(2));

 private:
  std::unique_ptr<ix::WebSocket> socket_;
  mutable std::mutex mutex_;
  std::condition_variable changed_;
  std::deque<std::string> messages_;
  bool open_ = false;
};

}  // namespace rmm::testing
