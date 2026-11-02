#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <string_view>
#include <unordered_map>

#include <nlohmann/json_fwd.hpp>

#include "core/monitors.h"
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
    std::string subscribedMonitor;  // GUID, empty when not subscribed
  };

  void sendMonitors(ClientId client);
  void sendMonitor(ClientId client, const MonitorState& monitor);
  void sendError(ClientId client, std::string_view code, std::string_view message);
  void sendJson(ClientId client, const nlohmann::json& message);

  const ReaperProject& project_;
  Send send_;
  std::unordered_map<ClientId, Client> clients_;
};

}  // namespace rmm
