#include "core/monitor_core.h"

#include <nlohmann/json.hpp>

#include "core/monitors.h"

namespace rmm {

using nlohmann::json;

namespace {

// Same monitor, same sources (ids and names) in the same order; levels may differ.
bool sameStructure(const MonitorState& a, const MonitorState& b) {
  if (a.monitor != b.monitor || a.sources.size() != b.sources.size()) return false;
  for (size_t i = 0; i < a.sources.size(); ++i) {
    if (a.sources[i].id != b.sources[i].id || a.sources[i].name != b.sources[i].name) return false;
  }
  return true;
}

}  // namespace

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
    sendMonitors(client, monitorsOf(project_));
    return;
  }

  if (type == "subscribe") {
    if (!message.contains("monitorId") || !message["monitorId"].is_string()) {
      sendError(client, "invalid_message", "subscribe needs a string 'monitorId'");
      return;
    }
    const std::string monitorId = message["monitorId"];
    const auto monitor = monitorState(project_, monitorId);
    if (!monitor) {
      sendError(client, "not_found", "no monitor with id " + monitorId);
      return;
    }
    state.subscribedMonitor = monitorId;
    sendMonitor(client, std::move(*monitor));
    return;
  }

  sendError(client, "unknown_type", "unknown message type: " + type);
}

void MonitorCore::sendMonitor(ClientId client, MonitorState monitor) {
  json sources = json::array();
  for (const Source& source : monitor.sources) {
    sources.push_back({{"id", source.id}, {"name", source.name}, {"level", source.level}});
  }
  sendJson(client, {{"type", "monitor"},
                    {"id", monitor.monitor.id},
                    {"name", monitor.monitor.name},
                    {"sources", sources}});
  clients_[client].monitor = std::move(monitor);
}

void MonitorCore::projectChanged() {
  const std::vector<Monitor> monitors = monitorsOf(project_);
  for (auto& [id, client] : clients_) {
    if (!client.welcomed) continue;
    if (client.monitors != monitors) sendMonitors(id, monitors);
    if (!client.subscribedMonitor.empty()) subscribedMonitorChanged(id);
  }
}

void MonitorCore::subscribedMonitorChanged(ClientId client) {
  Client& state = clients_[client];
  auto monitor = monitorState(project_, state.subscribedMonitor);
  if (!monitor) {
    sendJson(client, {{"type", "monitor_removed"}, {"id", state.subscribedMonitor}});
    state.subscribedMonitor.clear();
    state.monitor = {};
    return;
  }
  // Level-only differences are not structure changes.
  if (!sameStructure(*monitor, state.monitor)) sendMonitor(client, std::move(*monitor));
}

void MonitorCore::sendMonitors(ClientId client, std::vector<Monitor> monitors) {
  json list = json::array();
  for (const Monitor& monitor : monitors) {
    list.push_back({{"id", monitor.id}, {"name", monitor.name}});
  }
  sendJson(client, {{"type", "monitors"}, {"monitors", list}});
  clients_[client].monitors = std::move(monitors);
}

void MonitorCore::sendError(ClientId client, std::string_view code, std::string_view message) {
  sendJson(client, {{"type", "error"}, {"code", code}, {"message", message}});
}

void MonitorCore::sendJson(ClientId client, const nlohmann::json& message) {
  // Track names come from REAPER; never throw on invalid UTF-8, replace it instead.
  send_(client, message.dump(-1, ' ', false, json::error_handler_t::replace));
}

}  // namespace rmm
