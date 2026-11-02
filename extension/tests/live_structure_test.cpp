// Live structure changes: the fake project is edited while clients are connected, and
// the clients see the new monitors list / monitor state without reconnecting.
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
const std::string kDrums = "{1B6A2C10-0003-4A3E-9C1D-000000000003}";
const std::string kVocalMonitor = "{1B6A2C10-0010-4A3E-9C1D-000000000010}";
const std::string kDrumsMonitor = "{1B6A2C10-0011-4A3E-9C1D-000000000011}";

constexpr auto kQuiet = std::chrono::milliseconds(100);

FakeProject bandProject() {
  FakeProject project;
  project.trackList = {
      {kVocal, "Wokal"},
      {kGuitar, "Gitara"},
      {kDrums, "Perkusja"},
      {kVocalMonitor, "Odsłuch: Wokal"},
  };
  project.receiveLists[kVocalMonitor] = {{kGuitar, 0.5}, {kVocal, 1.0}};
  return project;
}

// A server on the project with one connected, welcomed client.
struct Session {
  explicit Session(FakeProject& project)
      : port(nextTestPort()), server(project, port, "127.0.0.1"), client((start(), port)) {
    REQUIRE(client.isOpen());
    client.send(R"({"type":"hello","protocolVersion":1})");
    REQUIRE(next()["type"] == "welcome");
    REQUIRE(next()["type"] == "monitors");
  }
  ~Session() { server.stop(); }

  void start() {
    std::string error;
    REQUIRE_MESSAGE(server.start(&error), error);
  }

  json next() {
    const auto message = client.nextMessage(server);
    REQUIRE_MESSAGE(message.has_value(), "no message");
    return json::parse(*message);
  }

  void subscribe(const std::string& monitorId) {
    client.send(json{{"type", "subscribe"}, {"monitorId", monitorId}}.dump());
    REQUIRE(next()["type"] == "monitor");
  }

  // Nothing more arrives for a while.
  void expectSilence() {
    const auto extra = client.nextMessage(server, kQuiet);
    CHECK_MESSAGE(!extra.has_value(), "unexpected message " << extra.value_or(""));
  }

  int port;
  MixerServer server;
  TestClient client;
};

json monitorsList(std::initializer_list<std::pair<std::string, std::string>> monitors) {
  json list = json::array();
  for (const auto& [id, name] : monitors) list.push_back({{"id", id}, {"name", name}});
  return list;
}

}  // namespace

TEST_CASE("a new monitor track shows up in the monitors list") {
  FakeProject project = bandProject();
  Session session(project);

  project.trackList.push_back({kDrumsMonitor, "Odsłuch: Perkusja"});
  project.changed();

  const json message = session.next();
  CHECK(message["type"] == "monitors");
  CHECK(message["monitors"] ==
        monitorsList({{kVocalMonitor, "Wokal"}, {kDrumsMonitor, "Perkusja"}}));
  session.expectSilence();
}

TEST_CASE("a removed monitor track disappears from the monitors list") {
  FakeProject project = bandProject();
  project.trackList.push_back({kDrumsMonitor, "Odsłuch: Perkusja"});
  Session session(project);

  project.trackList.erase(project.trackList.begin() + 3);  // Odsłuch: Wokal
  project.changed();

  const json message = session.next();
  CHECK(message["type"] == "monitors");
  CHECK(message["monitors"] == monitorsList({{kDrumsMonitor, "Perkusja"}}));
  session.expectSilence();
}

TEST_CASE("nothing is sent when the change does not touch what the client sees") {
  FakeProject project = bandProject();
  Session session(project);
  session.subscribe(kVocalMonitor);

  SUBCASE("spurious change notification") {}
  SUBCASE("a track that is no monitor and no source is added") {
    project.trackList.push_back({"{1B6A2C10-0004-4A3E-9C1D-000000000004}", "Bas"});
  }
  SUBCASE("a track that is no source is renamed") { project.trackList[2].name = "Bębny"; }
  project.changed();

  session.expectSilence();
}

TEST_CASE("the subscribed client gets the full monitor when its sources change") {
  FakeProject project = bandProject();
  Session session(project);
  session.subscribe(kVocalMonitor);

  json expectedSources;
  SUBCASE("a receive is added") {
    project.receiveLists[kVocalMonitor].push_back({kDrums, 0.25});
    expectedSources = {{{"id", kGuitar}, {"name", "Gitara"}, {"level", 0.5}},
                       {{"id", kVocal}, {"name", "Wokal"}, {"level", 1.0}},
                       {{"id", kDrums}, {"name", "Perkusja"}, {"level", 0.25}}};
  }
  SUBCASE("a receive is removed") {
    project.receiveLists[kVocalMonitor].erase(project.receiveLists[kVocalMonitor].begin());
    expectedSources = {{{"id", kVocal}, {"name", "Wokal"}, {"level", 1.0}}};
  }
  SUBCASE("a source track is renamed") {
    project.trackList[1].name = "Gitara akustyczna";
    expectedSources = {{{"id", kGuitar}, {"name", "Gitara akustyczna"}, {"level", 0.5}},
                       {{"id", kVocal}, {"name", "Wokal"}, {"level", 1.0}}};
  }
  SUBCASE("a source track is deleted") {
    project.trackList.erase(project.trackList.begin() + 1);
    expectedSources = {{{"id", kVocal}, {"name", "Wokal"}, {"level", 1.0}}};
  }
  project.changed();

  const json message = session.next();
  CHECK(message["type"] == "monitor");
  CHECK(message["id"] == kVocalMonitor);
  CHECK(message["name"] == "Wokal");
  CHECK(message["sources"] == expectedSources);
  session.expectSilence();
}

TEST_CASE("a level-only change sends no full monitor") {
  FakeProject project = bandProject();
  Session session(project);
  session.subscribe(kVocalMonitor);

  project.receiveLists[kVocalMonitor][0].level = 0.1;
  project.changed();

  session.expectSilence();
}

TEST_CASE("renaming the subscribed monitor updates the list and the monitor") {
  FakeProject project = bandProject();
  Session session(project);
  session.subscribe(kVocalMonitor);

  project.trackList[3].name = "Odsłuch: Śpiew";
  project.changed();

  json message = session.next();
  CHECK(message["type"] == "monitors");
  CHECK(message["monitors"] == monitorsList({{kVocalMonitor, "Śpiew"}}));
  message = session.next();
  CHECK(message["type"] == "monitor");
  CHECK(message["name"] == "Śpiew");
  session.expectSilence();
}

TEST_CASE("the subscribed client learns that its monitor is gone") {
  FakeProject project = bandProject();
  project.trackList.push_back({kDrumsMonitor, "Odsłuch: Perkusja"});
  Session session(project);
  session.subscribe(kVocalMonitor);

  SUBCASE("monitor track deleted") { project.trackList.erase(project.trackList.begin() + 3); }
  SUBCASE("monitor track renamed without the prefix") { project.trackList[3].name = "Wokal mix"; }
  project.changed();

  json message = session.next();
  CHECK(message["type"] == "monitors");
  CHECK(message["monitors"] == monitorsList({{kDrumsMonitor, "Perkusja"}}));
  message = session.next();
  CHECK(message["type"] == "monitor_removed");
  CHECK(message["id"] == kVocalMonitor);
  session.expectSilence();

  // The subscription is over: bringing the track back only updates the list.
  project.trackList = bandProject().trackList;
  project.trackList.push_back({kDrumsMonitor, "Odsłuch: Perkusja"});
  project.changed();
  message = session.next();
  CHECK(message["type"] == "monitors");
  session.expectSilence();
}

TEST_CASE("only the client subscribed to a removed monitor gets monitor_removed") {
  FakeProject project = bandProject();
  project.trackList.push_back({kDrumsMonitor, "Odsłuch: Perkusja"});
  Session session(project);
  session.subscribe(kDrumsMonitor);
  TestClient vocalist(session.port);
  vocalist.send(R"({"type":"hello","protocolVersion":1})");
  vocalist.send(json{{"type", "subscribe"}, {"monitorId", kVocalMonitor}}.dump());
  for (const char* type : {"welcome", "monitors", "monitor"}) {
    const auto message = vocalist.nextMessage(session.server);
    REQUIRE(message.has_value());
    CHECK(json::parse(*message)["type"] == type);
  }

  project.trackList.erase(project.trackList.begin() + 3);  // Odsłuch: Wokal
  project.changed();

  CHECK(session.next()["type"] == "monitors");
  session.expectSilence();
  json message = json::parse(vocalist.nextMessage(session.server).value_or("{}"));
  CHECK(message["type"] == "monitors");
  message = json::parse(vocalist.nextMessage(session.server).value_or("{}"));
  CHECK(message["type"] == "monitor_removed");
}

TEST_CASE("moving tracks does not change which monitor and sources the client sees") {
  FakeProject project = bandProject();
  Session session(project);
  session.subscribe(kVocalMonitor);

  // Odsłuch: Wokal to the top, Gitara to the bottom; receives keep their order.
  project.trackList = {
      {kVocalMonitor, "Odsłuch: Wokal"}, {kVocal, "Wokal"}, {kDrums, "Perkusja"}, {kGuitar, "Gitara"}};
  project.changed();
  session.expectSilence();

  // A later change still refers to the same tracks by GUID.
  project.trackList[3].name = "Gitara elektryczna";
  project.changed();
  const json message = session.next();
  CHECK(message["type"] == "monitor");
  CHECK(message["sources"][0] ==
        json{{"id", kGuitar}, {"name", "Gitara elektryczna"}, {"level", 0.5}});
}

TEST_CASE("switching projects shows the monitors of the new project") {
  FakeProject project = bandProject();
  Session session(project);
  session.subscribe(kVocalMonitor);

  const std::string otherBass = "{2C7B3D21-0001-4A3E-9C1D-000000000001}";
  const std::string otherMonitor = "{2C7B3D21-0010-4A3E-9C1D-000000000010}";
  project.trackList = {{otherBass, "Bas"}, {otherMonitor, "Odsłuch: Bas"}};
  project.receiveLists = {{otherMonitor, {{otherBass, 1.0}}}};
  project.changed();

  json message = session.next();
  CHECK(message["type"] == "monitors");
  CHECK(message["monitors"] == monitorsList({{otherMonitor, "Bas"}}));
  message = session.next();
  CHECK(message["type"] == "monitor_removed");
  CHECK(message["id"] == kVocalMonitor);
  session.expectSilence();
}
