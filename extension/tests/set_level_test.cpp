#include <doctest/doctest.h>

#include <chrono>
#include <map>
#include <vector>
#include <nlohmann/json.hpp>
#include <thread>

#include "fake_project.h"
#include "test_client.h"
#include "transport/mixer_server.h"

using nlohmann::json;
using namespace rmm;
using namespace rmm::testing;

namespace {

const std::string kMonitor = "{1B6A2C10-0010-4A3E-9C1D-000000000010}";
const std::string kVocals = "{1B6A2C10-0001-4A3E-9C1D-000000000001}";
const std::string kGuitar = "{1B6A2C10-0002-4A3E-9C1D-000000000002}";

std::string setLevel(const std::string& sourceId, double level) {
  return json{{"type", "set_level"}, {"monitorId", kMonitor}, {"sourceId", sourceId}, {"level", level}}
      .dump();
}

}  // namespace

TEST_CASE("set_level messages for one receive within one timer tick write only the last value") {
  FakeProject project;
  project.trackList = {{kVocals, "Wokal"}, {kGuitar, "Gitara"}, {kMonitor, "Odsłuch: Wokal"}};
  project.receiveLists[kMonitor] = {{kVocals, 1.0}, {kGuitar, 1.0}};

  const int port = nextTestPort();
  MixerServer server(project, port, "127.0.0.1");
  REQUIRE(server.start());
  TestClient client(port);
  REQUIRE(client.isOpen());
  client.send(R"({"type":"hello","protocolVersion":2})");
  REQUIRE(client.nextMessage(server));  // welcome
  REQUIRE(client.nextMessage(server));  // monitors

  // A fast drag: several values for the guitar and one for the vocals arrive before the
  // main-thread timer runs again.
  client.send(setLevel(kGuitar, 0.9));
  client.send(setLevel(kVocals, 0.5));
  client.send(setLevel(kGuitar, 0.8));
  client.send(setLevel(kGuitar, 0.7));
  std::this_thread::sleep_for(std::chrono::milliseconds(300));
  server.pump();

  std::map<std::string, std::vector<double>> writesBySource;
  for (const auto& write : project.levelWrites) {
    CHECK(write.trackGuid == kMonitor);
    writesBySource[write.sourceGuid].push_back(write.level);
  }
  CHECK(writesBySource[kGuitar] == std::vector<double>{0.7});
  CHECK(writesBySource[kVocals] == std::vector<double>{0.5});
  server.stop();
}

namespace {

std::string setOutputLevel(const std::string& monitorId, double level) {
  return json{{"type", "set_output_level"}, {"monitorId", monitorId}, {"level", level}}.dump();
}

}  // namespace

TEST_CASE("set_output_level messages within one timer tick write only the last value") {
  FakeProject project;
  project.trackList = {{kMonitor, "Odsłuch: Wokal"}};
  project.hardwareSendLists[kMonitor] = {{1.0}};

  const int port = nextTestPort();
  MixerServer server(project, port, "127.0.0.1");
  REQUIRE(server.start());
  TestClient client(port);
  REQUIRE(client.isOpen());
  client.send(R"({"type":"hello","protocolVersion":2})");
  REQUIRE(client.nextMessage(server));  // welcome
  REQUIRE(client.nextMessage(server));  // monitors

  client.send(setOutputLevel(kMonitor, 0.9));
  client.send(setOutputLevel(kMonitor, 0.4));
  client.send(setOutputLevel(kMonitor, 0.2));
  std::this_thread::sleep_for(std::chrono::milliseconds(300));
  server.pump();

  REQUIRE(project.hardwareSendWrites.size() == 1);
  CHECK(project.hardwareSendWrites[0].trackGuid == kMonitor);
  CHECK(project.hardwareSendWrites[0].index == 0);
  CHECK(project.hardwareSendWrites[0].level == 0.2);
  server.stop();
}

TEST_CASE("set_output_level writes nothing when the monitor has two hardware sends") {
  FakeProject project;
  project.trackList = {{kMonitor, "Odsłuch: Wokal"}};
  project.hardwareSendLists[kMonitor] = {{1.0}, {0.5}};

  const int port = nextTestPort();
  MixerServer server(project, port, "127.0.0.1");
  REQUIRE(server.start());
  TestClient client(port);
  REQUIRE(client.isOpen());
  client.send(R"({"type":"hello","protocolVersion":2})");
  REQUIRE(client.nextMessage(server));  // welcome
  REQUIRE(client.nextMessage(server));  // monitors

  client.send(setOutputLevel(kMonitor, 0.5));
  const auto reply = client.nextMessage(server);
  REQUIRE(reply.has_value());
  CHECK(json::parse(*reply)["code"] == "output_unavailable");
  server.pump();
  CHECK(project.hardwareSendWrites.empty());
  server.stop();
}
