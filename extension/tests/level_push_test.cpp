// Level push: a source level changed in REAPER or by another phone reaches every client
// subscribed to that monitor (the sender too), and nobody else.
#include <doctest/doctest.h>

#include <nlohmann/json.hpp>

#include "fake_project.h"
#include "test_client.h"
#include "transport/mixer_server.h"

using nlohmann::json;
using namespace rmm;
using namespace rmm::testing;

namespace {

const std::string kVocal = "{1B6A2C10-0001-4A3E-9C1D-000000000001}";
const std::string kGuitar = "{1B6A2C10-0002-4A3E-9C1D-000000000002}";
const std::string kVocalMonitor = "{1B6A2C10-0010-4A3E-9C1D-000000000010}";
const std::string kGuitarMonitor = "{1B6A2C10-0020-4A3E-9C1D-000000000020}";

constexpr auto kQuiet = std::chrono::milliseconds(100);

FakeProject bandProject() {
  FakeProject project;
  project.trackList = {
      {kVocal, "Wokal"},
      {kGuitar, "Gitara"},
      {kVocalMonitor, "Odsłuch: Wokal"},
      {kGuitarMonitor, "Odsłuch: Gitara"},
  };
  project.receiveLists[kVocalMonitor] = {{kGuitar, 0.5}, {kVocal, 1.0}};
  project.receiveLists[kGuitarMonitor] = {{kGuitar, 1.0}, {kVocal, 0.5}};
  return project;
}

// A phone connected to the server and subscribed to one monitor.
struct Phone {
  Phone(MixerServer& server, int port, const std::string& monitorId)
      : server(server), client(port) {
    REQUIRE(client.isOpen());
    client.send(R"({"type":"hello","protocolVersion":1})");
    client.send(json{{"type", "subscribe"}, {"monitorId", monitorId}}.dump());
    for (const char* type : {"welcome", "monitors", "monitor"}) REQUIRE(next()["type"] == type);
  }

  json next() {
    const auto message = client.nextMessage(server);
    REQUIRE_MESSAGE(message.has_value(), "no message");
    return json::parse(*message);
  }

  void expectSilence() {
    const auto extra = client.nextMessage(server, kQuiet);
    CHECK_MESSAGE(!extra.has_value(), "unexpected message " << extra.value_or(""));
  }

  MixerServer& server;
  TestClient client;
};

json levelMessage(const std::string& monitorId, const std::string& sourceId, double level) {
  return {{"type", "level"}, {"monitorId", monitorId}, {"sourceId", sourceId}, {"level", level}};
}

struct Band {
  Band() : port(nextTestPort()), server(project, port, "127.0.0.1") {
    std::string error;
    REQUIRE_MESSAGE(server.start(&error), error);
  }
  ~Band() { server.stop(); }

  FakeProject project = bandProject();
  int port;
  MixerServer server;
};

}  // namespace

TEST_CASE("a level changed in REAPER reaches every phone showing that monitor") {
  Band band;
  Phone vocalist(band.server, band.port, kVocalMonitor);
  Phone backingVocalist(band.server, band.port, kVocalMonitor);
  Phone guitarist(band.server, band.port, kGuitarMonitor);

  band.project.receiveLists[kVocalMonitor][0].level = 0.25;  // moved with the mouse
  band.project.changed();

  CHECK(vocalist.next() == levelMessage(kVocalMonitor, kGuitar, 0.25));
  CHECK(backingVocalist.next() == levelMessage(kVocalMonitor, kGuitar, 0.25));
  vocalist.expectSilence();
  backingVocalist.expectSilence();
  guitarist.expectSilence();
}

TEST_CASE("a level set from one phone comes back to it and reaches the other phone") {
  Band band;
  Phone vocalist(band.server, band.port, kVocalMonitor);
  Phone backingVocalist(band.server, band.port, kVocalMonitor);
  Phone guitarist(band.server, band.port, kGuitarMonitor);

  SUBCASE("REAPER reports the phone's write like any other change") {}
  SUBCASE("REAPER does not report the phone's own write") {
    band.project.notifiesOwnWrites = false;
  }
  vocalist.client.send(json{{"type", "set_level"},
                            {"monitorId", kVocalMonitor},
                            {"sourceId", kGuitar},
                            {"level", 0.25}}
                           .dump());

  CHECK(vocalist.next() == levelMessage(kVocalMonitor, kGuitar, 0.25));
  CHECK(backingVocalist.next() == levelMessage(kVocalMonitor, kGuitar, 0.25));
  vocalist.expectSilence();
  backingVocalist.expectSilence();
  guitarist.expectSilence();
}
