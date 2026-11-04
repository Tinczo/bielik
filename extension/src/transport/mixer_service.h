#pragma once

#include <memory>
#include <string>

#include "core/reaper_project.h"
#include "transport/mixer_server.h"

namespace rmm {

// The extension's settings, set by the person preparing the session.
struct Settings {
  int port = kDefaultPort;
  std::string password;  // band password; empty = none
};

// Where settings persist (REAPER ExtState in production, in memory in tests).
class SettingsStore {
 public:
  virtual ~SettingsStore() = default;
  virtual Settings load() const = 0;
  virtual void save(const Settings& settings) = 0;
};

// Runs the MixerServer with the stored settings and applies new settings while REAPER
// runs: a new port restarts the server on that port, a new password applies to the next
// hello. Main thread only.
class MixerService {
 public:
  MixerService(ReaperProject& project, SettingsStore& store, std::string host = "0.0.0.0");

  // Starts the server with the stored settings. On failure (e.g. port taken) the service
  // stays without a server until applySettings() succeeds.
  bool start(std::string* error = nullptr);
  void stop();
  void pump();

  Settings settings() const { return settings_; }

  // Applies and saves the settings. If the new port cannot be bound, nothing changes
  // (the old server keeps running, nothing is saved) and false is returned.
  bool applySettings(const Settings& settings, std::string* error = nullptr);

 private:
  std::unique_ptr<MixerServer> startServer(const Settings& settings, std::string* error);

  ReaperProject& project_;
  SettingsStore& store_;
  std::string host_;
  Settings settings_;
  std::unique_ptr<MixerServer> server_;
};

}  // namespace rmm
