#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <string_view>
#include <unordered_map>

#include "core/reaper_project.h"

namespace rmm {

using ClientId = std::uint64_t;

// Version of the wire protocol described in docs/protocol.md.
inline constexpr int kProtocolVersion = 1;

// Monitors core: builds the monitors model from the project and handles protocol
// messages. Knows neither the REAPER API nor sockets; everything runs on the main thread.
class MonitorCore {
 public:
  // Called for every outgoing text message.
  using Send = std::function<void(ClientId, std::string)>;

  MonitorCore(const ReaperProject& project, Send send);

  void clientConnected(ClientId client);
  void clientDisconnected(ClientId client);
  void handleMessage(ClientId client, std::string_view text);

 private:
  struct Client {
    bool welcomed = false;
  };

  void sendJson(ClientId client, const std::string& json);

  const ReaperProject& project_;
  Send send_;
  std::unordered_map<ClientId, Client> clients_;
};

}  // namespace rmm
