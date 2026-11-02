#pragma once

#include <string>

#include "core/monitor_core.h"
#include "core/reaper_project.h"
#include "transport/websocket_transport.h"

namespace rmm {

// Default listening port; deliberately not 8080, which REAPER's web remote uses.
inline constexpr int kDefaultPort = 8790;

// The extension's server: WebSocket transport wired to the monitors core.
// pump() must be called on the main thread (REAPER timer in production, by hand in tests).
class MixerServer {
 public:
  MixerServer(const ReaperProject& project, int port, std::string host = "0.0.0.0");

  bool start(std::string* error = nullptr);
  void stop();

  // Main thread: delivers queued network events to the core.
  void pump();

 private:
  WebSocketTransport transport_;
  MonitorCore core_;
};

}  // namespace rmm
