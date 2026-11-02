#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

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
  // Called to close a client's connection, after the messages already sent to it.
  using Close = std::function<void(ClientId)>;

  MonitorCore(ReaperProject& project, Send send, Close close = {});

  // The band password hello must carry; empty means hello may omit it. Applies to the
  // next hello, connections already welcomed stay.
  void setPassword(std::string password);

  void clientConnected(ClientId client);
  void clientDisconnected(ClientId client);
  void handleMessage(ClientId client, std::string_view text);

  // Writes the levels requested by set_level since the last call to the project. Called
  // once per timer tick: many set_level for one receive within a tick write only the last
  // value.
  void applyPendingLevels();

 private:
  struct Client {
    bool welcomed = false;
    std::string subscribedMonitor;  // GUID, empty when not subscribed
  };

  void handleSetLevel(ClientId client, const nlohmann::json& message);
  void sendMonitors(ClientId client);
  void sendMonitor(ClientId client, const MonitorState& monitor);
  void sendError(ClientId client, std::string_view code, std::string_view message);
  void sendJson(ClientId client, const nlohmann::json& message);
  void refuse(ClientId client, std::string_view code, std::string_view message);

  ReaperProject& project_;
  Send send_;
  Close close_;
  std::string password_;
  std::unordered_map<ClientId, Client> clients_;

  struct PendingLevel {
    std::string monitorId;
    std::string sourceId;
    double level;
  };
  std::vector<PendingLevel> pendingLevels_;  // at most one per receive, in arrival order
};

}  // namespace rmm
