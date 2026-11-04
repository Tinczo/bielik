// Contract test: replays every shared example exchange from protocol/examples against
// the real server running on a fake project, through a real WebSocket client.
#include <doctest/doctest.h>

#include <filesystem>
#include <fstream>
#include <nlohmann/json.hpp>

#include "fake_project.h"
#include "test_client.h"
#include "transport/mixer_server.h"

namespace fs = std::filesystem;
using nlohmann::json;
using namespace rmm;
using namespace rmm::testing;

namespace {

json loadExample(const fs::path& path) {
  std::ifstream file(path);
  REQUIRE_MESSAGE(file.good(), "cannot open " << path.string());
  return json::parse(file);
}

// The protocol's matching rule (docs/protocol.md): every field of the expected message
// must be present and equal in the actual one; objects may carry extra fields.
bool matches(const json& expected, const json& actual) {
  if (expected.is_object()) {
    if (!actual.is_object()) return false;
    for (const auto& [key, value] : expected.items()) {
      if (!actual.contains(key) || !matches(value, actual[key])) return false;
    }
    return true;
  }
  if (expected.is_array()) {
    if (!actual.is_array() || actual.size() != expected.size()) return false;
    for (size_t i = 0; i < expected.size(); ++i) {
      if (!matches(expected[i], actual[i])) return false;
    }
    return true;
  }
  return expected == actual;
}

// Replaces the fake project's contents with a fixture's `project` object.
void load(FakeProject& project, const json& state) {
  project.trackList.clear();
  project.receiveLists.clear();
  for (const auto& track : state["tracks"]) {
    const std::string guid = track["guid"];
    project.trackList.push_back({guid, track["name"].get<std::string>()});
    for (const auto& receive : track.value("receives", json::array())) {
      project.receiveLists[guid].push_back(
          {receive["source"].get<std::string>(), receive["level"].get<double>()});
    }
  }
}

void replay(const json& example) {
  FakeProject project;
  load(project, example["project"]);
  const int port = nextTestPort();
  MixerServer server(project, port, "127.0.0.1");
  if (example.contains("settings")) {
    server.setPassword(example["settings"].value("password", std::string()));
  }
  std::string error;
  REQUIRE_MESSAGE(server.start(&error), error);
  TestClient client(port);
  REQUIRE(client.isOpen());

  int stepIndex = 0;
  bool closed = false;
  for (const auto& step : example["steps"]) {
    CAPTURE(stepIndex);
    if (step.contains("project")) {  // the project changes in REAPER
      load(project, step["project"]);
      project.changed();
    } else if (step.contains("closed")) {
      CHECK_MESSAGE(client.waitClosed(server), "expected the server to close the connection");
      closed = true;
    } else if (step.contains("client")) {
      const json& message = step["client"];
      client.send(message.is_string() ? message.get<std::string>() : message.dump());
    } else {
      const json& expected = step["server"];
      const auto received = client.nextMessage(server);
      REQUIRE_MESSAGE(received.has_value(), "no message, expected " << expected.dump());
      CAPTURE(*received);
      CHECK_MESSAGE(matches(expected, json::parse(*received)), "expected " << expected.dump());
    }
    ++stepIndex;
  }

  // Nothing unexpected follows, and the connection stays open unless the example closed it.
  const auto extra = client.nextMessage(server, std::chrono::milliseconds(100));
  CHECK_MESSAGE(!extra.has_value(), "unexpected message " << extra.value_or(""));
  if (!closed) CHECK(client.isOpen());
  server.stop();
}

}  // namespace

TEST_CASE("server follows every shared protocol example") {
  int count = 0;
  for (const auto& entry : fs::directory_iterator(PROTOCOL_EXAMPLES_DIR)) {
    if (entry.path().extension() != ".json") continue;
    SUBCASE(entry.path().filename().string().c_str()) { replay(loadExample(entry.path())); }
    ++count;
  }
  CHECK(count > 0);
}
