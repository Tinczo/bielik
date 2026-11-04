#include "transport/mixer_server.h"

namespace rmm {

MixerServer::MixerServer(ReaperProject& project, int port, std::string host)
    : project_(project),
      transport_(std::move(host), port),
      core_(
          project,
          [this](ClientId client, std::string text) { transport_.send(client, std::move(text)); },
          [this](ClientId client) { transport_.close(client); }),
      changeListener_(project_.addChangeListener([this] { core_.projectChanged(); })) {}

MixerServer::~MixerServer() { project_.removeChangeListener(changeListener_); }

void MixerServer::setPassword(std::string password) { core_.setPassword(std::move(password)); }

bool MixerServer::start(std::string* error) { return transport_.start(error); }

void MixerServer::stop() { transport_.stop(); }

void MixerServer::pump() {
  for (auto& event : transport_.takeEvents()) {
    switch (event.kind) {
      case WebSocketTransport::Event::Kind::Connected:
        core_.clientConnected(event.client);
        break;
      case WebSocketTransport::Event::Kind::Message:
        core_.handleMessage(event.client, event.text);
        break;
      case WebSocketTransport::Event::Kind::Disconnected:
        core_.clientDisconnected(event.client);
        break;
    }
  }
  core_.applyPendingLevels();
}

}  // namespace rmm
