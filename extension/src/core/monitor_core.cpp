#include "core/monitor_core.h"

#include <nlohmann/json.hpp>

#include "core/monitors.h"

namespace rmm {

using nlohmann::json;

MonitorCore::MonitorCore(const ReaperProject& project, Send send)
    : project_(project), send_(std::move(send)) {}

void MonitorCore::clientConnected(ClientId client) { clients_[client] = {}; }

void MonitorCore::clientDisconnected(ClientId client) { clients_.erase(client); }

void MonitorCore::handleMessage(ClientId client, std::string_view text) {
  const json message = json::parse(text);
  if (message["type"] == "hello") {
    clients_[client].welcomed = true;
    sendJson(client, json{{"type", "welcome"}, {"protocolVersion", kProtocolVersion}}.dump());

    json monitors = json::array();
    for (const Monitor& monitor : monitorsOf(project_)) {
      monitors.push_back({{"id", monitor.id}, {"name", monitor.name}});
    }
    sendJson(client, json{{"type", "monitors"}, {"monitors", monitors}}.dump());
  }
}

void MonitorCore::sendJson(ClientId client, const std::string& json) { send_(client, json); }

}  // namespace rmm
