// The extension's settings (port, band password): loaded from the settings store at
// start, and applied while REAPER runs — a new port restarts the server on that port.
#include <doctest/doctest.h>

#include <nlohmann/json.hpp>

#include "fake_project.h"
#include "test_client.h"
#include "transport/mixer_service.h"

using nlohmann::json;
using namespace rmm;
using namespace rmm::testing;

namespace {

// In-memory stand-in for REAPER's ExtState.
class FakeSettingsStore : public SettingsStore {
 public:
  Settings stored;
  Settings load() const override { return stored; }
  void save(const Settings& settings) override { stored = settings; }
};

json helloWith(const std::string& password) {
  return {{"type", "hello"}, {"protocolVersion", 1}, {"password", password}};
}

// Sends hello and returns the type of the server's answer ("welcome", "error", or "" if none).
std::string answerToHello(MixerService& service, int port, const std::string& password,
                          std::string* errorCode = nullptr) {
  TestClient client(port);
  if (!client.isOpen()) return "";
  client.send(helloWith(password).dump());
  const auto answer = client.nextMessage([&service] { service.pump(); });
  if (!answer) return "";
  const json message = json::parse(*answer);
  if (errorCode && message.contains("code")) *errorCode = message["code"];
  return message["type"];
}

}  // namespace

TEST_CASE("default settings use a port other than REAPER web remote's 8080") {
  CHECK(Settings{}.port == 8790);
  CHECK(Settings{}.password.empty());
}

TEST_CASE("service listens on the port and checks the password from the stored settings") {
  FakeProject project;
  FakeSettingsStore store;
  store.stored = {nextTestPort(), "próba2026"};
  MixerService service(project, store, "127.0.0.1");
  std::string error;
  REQUIRE_MESSAGE(service.start(&error), error);

  CHECK(answerToHello(service, store.stored.port, "próba2026") == "welcome");
  std::string code;
  CHECK(answerToHello(service, store.stored.port, "zgaduję", &code) == "error");
  CHECK(code == "bad_password");
  service.stop();
}

TEST_CASE("changing the port restarts the server on the new port without restarting REAPER") {
  FakeProject project;
  FakeSettingsStore store;
  const int oldPort = nextTestPort();
  const int newPort = nextTestPort();
  store.stored = {oldPort, ""};
  MixerService service(project, store, "127.0.0.1");
  REQUIRE(service.start());
  REQUIRE(answerToHello(service, oldPort, "") == "welcome");

  std::string error;
  REQUIRE_MESSAGE(service.applySettings({newPort, ""}, &error), error);

  CHECK(answerToHello(service, newPort, "") == "welcome");
  CHECK_FALSE(TestClient(oldPort).isOpen());
  CHECK(store.stored.port == newPort);
  service.stop();
}

TEST_CASE("the server can go back to a port it used a moment ago") {
  FakeProject project;
  FakeSettingsStore store;
  const int firstPort = nextTestPort();
  const int secondPort = nextTestPort();
  store.stored = {firstPort, ""};
  MixerService service(project, store, "127.0.0.1");
  REQUIRE(service.start());
  REQUIRE(answerToHello(service, firstPort, "") == "welcome");

  REQUIRE(service.applySettings({secondPort, ""}));
  std::string error;
  REQUIRE_MESSAGE(service.applySettings({firstPort, ""}, &error), error);

  CHECK(answerToHello(service, firstPort, "") == "welcome");
  service.stop();
}

TEST_CASE("changing the password takes effect for the next hello and is saved") {
  FakeProject project;
  FakeSettingsStore store;
  const int port = nextTestPort();
  store.stored = {port, "stare"};
  MixerService service(project, store, "127.0.0.1");
  REQUIRE(service.start());

  REQUIRE(service.applySettings({port, "nowe"}));

  CHECK(answerToHello(service, port, "nowe") == "welcome");
  CHECK(answerToHello(service, port, "stare") == "error");
  CHECK(store.stored.password == "nowe");
  service.stop();
}

TEST_CASE("a port that cannot be bound keeps the old server and settings") {
  FakeProject project;
  FakeSettingsStore store;
  const int port = nextTestPort();
  const int takenPort = nextTestPort();
  MixerServer squatter(project, takenPort, "127.0.0.1");
  REQUIRE(squatter.start());
  store.stored = {port, ""};
  MixerService service(project, store, "127.0.0.1");
  REQUIRE(service.start());

  std::string error;
  CHECK_FALSE(service.applySettings({takenPort, "nowe"}, &error));
  CHECK_FALSE(error.empty());

  CHECK(answerToHello(service, port, "") == "welcome");
  CHECK(store.stored.port == port);
  CHECK(store.stored.password.empty());
  service.stop();
  squatter.stop();
}

TEST_CASE("a server that could not start at load can be started by choosing another port") {
  FakeProject project;
  FakeSettingsStore store;
  const int takenPort = nextTestPort();
  const int freePort = nextTestPort();
  MixerServer squatter(project, takenPort, "127.0.0.1");
  REQUIRE(squatter.start());
  store.stored = {takenPort, ""};
  MixerService service(project, store, "127.0.0.1");
  CHECK_FALSE(service.start());

  REQUIRE(service.applySettings({freePort, ""}));

  CHECK(answerToHello(service, freePort, "") == "welcome");
  service.stop();
  squatter.stop();
}

TEST_CASE("unloading the extension closes the connections and frees the port") {
  FakeProject project;
  FakeSettingsStore store;
  const int port = nextTestPort();
  store.stored = {port, ""};
  {
    MixerService service(project, store, "127.0.0.1");
    REQUIRE(service.start());
    TestClient client(port);
    REQUIRE(client.isOpen());
    client.send(helloWith("").dump());
    REQUIRE(client.nextMessage([&service] { service.pump(); }));

    service.stop();

    CHECK(client.waitClosed([] {}));
    CHECK_FALSE(TestClient(port).isOpen());
  }

  // REAPER started again: the port can be bound at once.
  MixerService restarted(project, store, "127.0.0.1");
  std::string error;
  CHECK_MESSAGE(restarted.start(&error), error);
  restarted.stop();
}

TEST_CASE("destroying a running service without stop() still shuts it down cleanly") {
  FakeProject project;
  FakeSettingsStore store;
  const int port = nextTestPort();
  store.stored = {port, ""};
  auto service = std::make_unique<MixerService>(project, store, "127.0.0.1");
  REQUIRE(service->start());
  TestClient client(port);
  REQUIRE(client.isOpen());

  service.reset();

  CHECK(client.waitClosed([] {}));
  MixerService restarted(project, store, "127.0.0.1");
  CHECK(restarted.start());
  restarted.stop();
}

TEST_CASE("stopping twice, or stopping a service that never started, is harmless") {
  FakeProject project;
  FakeSettingsStore store;
  store.stored = {nextTestPort(), ""};
  MixerService neverStarted(project, store, "127.0.0.1");
  neverStarted.stop();

  MixerService service(project, store, "127.0.0.1");
  REQUIRE(service.start());
  service.stop();
  service.stop();
  service.pump();
}
