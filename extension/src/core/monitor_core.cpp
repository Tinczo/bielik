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
  const json message = json::parse(text, nullptr, /*allow_exceptions=*/false);
  if (!message.is_object() || !message.contains("type") || !message["type"].is_string()) {
    sendError(client, "invalid_message", "expected a JSON object with a string 'type'");
    return;
  }
  const std::string type = message["type"];
  Client& state = clients_[client];

  if (!state.welcomed) {
    if (type != "hello") {
      sendError(client, "handshake_required", "send hello first");
      return;
    }
    if (!message.contains("protocolVersion") || !message["protocolVersion"].is_number_integer()) {
      sendError(client, "invalid_message", "hello needs an integer 'protocolVersion'");
      return;
    }
    state.welcomed = true;
    sendJson(client, {{"type", "welcome"}, {"protocolVersion", kProtocolVersion}});
    sendMonitors(client);
    return;
  }

  sendError(client, "unknown_type", "unknown message type: " + type);
}

void MonitorCore::sendMonitors(ClientId client) {
  json monitors = json::array();
  for (const Monitor& monitor : monitorsOf(project_)) {
    monitors.push_back({{"id", monitor.id}, {"name", monitor.name}});
  }
  sendJson(client, {{"type", "monitors"}, {"monitors", monitors}});
}

void MonitorCore::sendError(ClientId client, std::string_view code, std::string_view message) {
  sendJson(client, {{"type", "error"}, {"code", code}, {"message", message}});
}

void MonitorCore::sendJson(ClientId client, const nlohmann::json& message) {
  // Track names come from REAPER; never throw on invalid UTF-8, replace it instead.
  send_(client, message.dump(-1, ' ', false, json::error_handler_t::replace));
}

}  // namespace rmm
