#pragma once

#include <memory>
#include <string>

namespace rmm {

// DNS-SD service type the extension announces; Bielik browses for it (docs/protocol.md).
inline constexpr const char* kMdnsServiceType = "_reaper-mixer._tcp";

// Announces the extension on the local network over mDNS (DNS-SD), as an instance
// named after the computer, so Bielik finds the laptop without typing its address.
// Uses the Windows 10+ DNS-SD API (DnsServiceRegister). Not covered by automated
// tests; checked by hand on a real Wi-Fi network.
class MdnsAdvertiser {
 public:
  MdnsAdvertiser();
  ~MdnsAdvertiser();  // withdraws the announcement

  MdnsAdvertiser(const MdnsAdvertiser&) = delete;
  MdnsAdvertiser& operator=(const MdnsAdvertiser&) = delete;

  // Announces the service on `port`, replacing any earlier announcement (call it
  // again when the port changes). Registration completes in the background.
  bool announce(int port, std::string* error = nullptr);

  // Withdraws the announcement, if any. Blocks briefly until Windows confirms.
  void withdraw();

 private:
  struct Registration;
  std::unique_ptr<Registration> registration_;
};

}  // namespace rmm
