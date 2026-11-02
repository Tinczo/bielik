#include "core/monitor_core.h"

#include <algorithm>
#include <cmath>

#include <nlohmann/json.hpp>

#include "core/monitors.h"

namespace rmm {

using nlohmann::json;

MonitorCore::MonitorCore(ReaperProject& project, Send send, Close close)
    : project_(project), send_(std::move(send)), close_(std::move(close)) {}

void MonitorCore::setPassword(std::string password) { password_ = std::move(password); }

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
    if (message.contains("password") && !message["password"].is_string()) {
      sendError(client, "invalid_message", "hello 'password' must be a string");
      return;
    }
    if (message["protocolVersion"] != kProtocolVersion) {
      refuse(client, "unsupported_version",
             "server speaks protocol version " + std::to_string(kProtocolVersion));
      return;
    }
    if (message.value("password", std::string()) != password_) {
      refuse(client, "bad_password", "wrong password");
      return;
    }
    state.welcomed = true;
    sendJson(client, {{"type", "welcome"}, {"protocolVersion", kProtocolVersion}});
    sendMonitors(client);
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
    sendMonitor(client, *monitor);
    return;
  }

  if (type == "set_level") {
    handleSetLevel(client, message);
    return;
  }
  // Anything else sees the levels requested before it.
  applyPendingLevels();

  sendError(client, "unknown_type", "unknown message type: " + type);
}

void MonitorCore::handleSetLevel(ClientId client, const nlohmann::json& message) {
  const auto isString = [&](const char* field) {
    return message.contains(field) && message[field].is_string();
  };
  if (!isString("monitorId") || !isString("sourceId") || !message.contains("level") ||
      !message["level"].is_number()) {
    sendError(client, "invalid_message",
              "set_level needs string 'monitorId' and 'sourceId' and a number 'level'");
    return;
  }
  const std::string monitorId = message["monitorId"];
  const std::string sourceId = message["sourceId"];
  const double level = message["level"];
  if (!std::isfinite(level) || level < 0) {
    sendError(client, "invalid_message", "set_level 'level' must be a finite number >= 0");
    return;
  }
  const auto monitor = monitorState(project_, monitorId);
  if (!monitor) {
    sendError(client, "not_found", "no monitor with id " + monitorId);
    return;
  }
  const bool hasSource = std::any_of(monitor->sources.begin(), monitor->sources.end(),
                                     [&](const Source& source) { return source.id == sourceId; });
  if (!hasSource) {
    sendError(client, "not_found", "monitor " + monitorId + " has no source " + sourceId);
    return;
  }
  for (PendingLevel& pending : pendingLevels_) {
    if (pending.monitorId == monitorId && pending.sourceId == sourceId) {
      pending.level = level;
      return;
    }
  }
  pendingLevels_.push_back({monitorId, sourceId, level});
}

void MonitorCore::applyPendingLevels() {
  for (const PendingLevel& pending : pendingLevels_) {
    project_.setReceiveLevel(pending.monitorId, pending.sourceId, pending.level);
  }
  pendingLevels_.clear();
}

void MonitorCore::sendMonitor(ClientId client, const MonitorState& monitor) {
  json sources = json::array();
  for (const Source& source : monitor.sources) {
    sources.push_back({{"id", source.id}, {"name", source.name}, {"level", source.level}});
  }
  sendJson(client, {{"type", "monitor"},
                    {"id", monitor.monitor.id},
                    {"name", monitor.monitor.name},
                    {"sources", sources}});
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

void MonitorCore::refuse(ClientId client, std::string_view code, std::string_view message) {
  sendError(client, code, message);
  clients_.erase(client);
  if (close_) close_(client);
}

void MonitorCore::sendJson(ClientId client, const nlohmann::json& message) {
  // Track names come from REAPER; never throw on invalid UTF-8, replace it instead.
  send_(client, message.dump(-1, ' ', false, json::error_handler_t::replace));
}

}  // namespace rmm
