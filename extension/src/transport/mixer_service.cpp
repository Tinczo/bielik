#include "transport/mixer_service.h"

namespace rmm {

MixerService::MixerService(ReaperProject& project, SettingsStore& store, std::string host)
    : project_(project), store_(store), host_(std::move(host)) {}

bool MixerService::start(std::string* error) {
  settings_ = store_.load();
  server_ = startServer(settings_, error);
  return server_ != nullptr;
}

void MixerService::stop() {
  if (server_) server_->stop();
  server_.reset();
}

void MixerService::pump() {
  if (server_) server_->pump();
}

bool MixerService::applySettings(const Settings& settings, std::string* error) {
  if (server_ && settings.port == settings_.port) {
    server_->setPassword(settings.password);
  } else {
    // Bind the new port before letting go of the old one, so a failure changes nothing.
    auto server = startServer(settings, error);
    if (!server) return false;
    stop();
    server_ = std::move(server);
  }
  settings_ = settings;
  store_.save(settings_);
  return true;
}

std::unique_ptr<MixerServer> MixerService::startServer(const Settings& settings,
                                                       std::string* error) {
  auto server = std::make_unique<MixerServer>(project_, settings.port, host_);
  server->setPassword(settings.password);
  if (!server->start(error)) return nullptr;
  return server;
}

}  // namespace rmm
