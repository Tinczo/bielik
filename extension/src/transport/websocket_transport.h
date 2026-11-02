#pragma once

#include <condition_variable>
#include <deque>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include "core/monitor_core.h"

namespace ix {
class WebSocket;
class WebSocketServer;
}  // namespace ix

namespace rmm {

// WebSocket server running on network threads (ADR-0001). Incoming events are queued
// under a mutex and drained on the main thread with takeEvents(); outgoing messages are
// queued with send() and written by a network-side sender thread.
class WebSocketTransport {
 public:
  struct Event {
    enum class Kind { Connected, Message, Disconnected };
    Kind kind;
    ClientId client;
    std::string text;
  };

  WebSocketTransport(std::string host, int port);
  ~WebSocketTransport();
  WebSocketTransport(const WebSocketTransport&) = delete;
  WebSocketTransport& operator=(const WebSocketTransport&) = delete;

  // Binds and starts listening. Returns false (with a reason) if the port is unavailable.
  bool start(std::string* error = nullptr);
  void stop();

  // Main thread: takes all events received since the last call.
  std::vector<Event> takeEvents();
  // Any thread: queues a text message for the client.
  void send(ClientId client, std::string text);
  // Any thread: closes the client's connection after the messages queued before.
  void close(ClientId client);

 private:
  struct Outgoing {
    ClientId client;
    std::string text;
    bool close = false;
  };

  void pushEvent(Event event);
  void senderLoop();

  std::unique_ptr<ix::WebSocketServer> server_;

  std::mutex inboxMutex_;
  std::vector<Event> inbox_;

  std::mutex outboxMutex_;
  std::condition_variable outboxReady_;
  std::deque<Outgoing> outbox_;
  bool stopping_ = false;
  std::thread sender_;

  // Open connections; guarded by connectionsMutex_. Pointers are removed on close,
  // before IXWebSocket destroys the connection.
  std::mutex connectionsMutex_;
  std::unordered_map<ClientId, ix::WebSocket*> connections_;
  ClientId nextClientId_ = 1;
};

}  // namespace rmm
