#include "transport/mdns_advertiser.h"

#include <windows.h>
#include <windns.h>

#include <atomic>
#include <iterator>
#include <string>

namespace rmm {
namespace {

// How long withdraw() waits for Windows to confirm each step.
constexpr DWORD kConfirmTimeoutMs = 2000;

std::wstring computerName() {
  wchar_t name[256] = {};
  DWORD size = static_cast<DWORD>(std::size(name));
  if (!GetComputerNameExW(ComputerNameDnsHostname, name, &size) || size == 0) return L"REAPER";
  return std::wstring(name, size);
}

std::wstring widen(const char* text) {
  std::wstring wide;
  for (; *text; ++text) wide += static_cast<wchar_t>(*text);  // ASCII only
  return wide;
}

}  // namespace

// One DNS-SD registration. Windows calls back on a thread-pool thread with this
// object as context, so it must outlive every pending callback.
struct MdnsAdvertiser::Registration {
  DNS_SERVICE_REGISTER_REQUEST request{};
  DNS_SERVICE_CANCEL cancel{};
  PDNS_SERVICE_INSTANCE instance = nullptr;
  HANDLE done = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  std::atomic<DWORD> status{DNS_REQUEST_PENDING};

  ~Registration() {
    if (instance) DnsServiceFreeInstance(instance);
    if (done) CloseHandle(done);
  }

  bool waitDone() const { return WaitForSingleObject(done, kConfirmTimeoutMs) == WAIT_OBJECT_0; }

  static VOID WINAPI onComplete(DWORD result, PVOID context, PDNS_SERVICE_INSTANCE copy) {
    if (copy) DnsServiceFreeInstance(copy);
    auto* self = static_cast<Registration*>(context);
    self->status = result;
    SetEvent(self->done);
  }
};

MdnsAdvertiser::MdnsAdvertiser() = default;

MdnsAdvertiser::~MdnsAdvertiser() { withdraw(); }

bool MdnsAdvertiser::announce(int port, std::string* error) {
  withdraw();
  if (port <= 0 || port > 0xFFFF) {
    if (error) *error = "invalid port " + std::to_string(port);
    return false;
  }

  const std::wstring host = computerName();
  const std::wstring instanceName = host + L"." + widen(kMdnsServiceType) + L".local";
  const std::wstring hostName = host + L".local";

  auto registration = std::make_unique<Registration>();
  registration->instance =
      DnsServiceConstructInstance(instanceName.c_str(), hostName.c_str(), nullptr, nullptr,
                                  static_cast<WORD>(port), 0, 0, 0, nullptr, nullptr);
  if (!registration->instance || !registration->done) {
    if (error) *error = "cannot prepare the mDNS service instance";
    return false;
  }
  auto& request = registration->request;
  request.Version = DNS_QUERY_REQUEST_VERSION1;
  request.InterfaceIndex = 0;  // all interfaces
  request.pServiceInstance = registration->instance;
  request.pRegisterCompletionCallback = &Registration::onComplete;
  request.pQueryContext = registration.get();

  const DWORD result = DnsServiceRegister(&request, &registration->cancel);
  if (result != DNS_REQUEST_PENDING) {
    if (error) *error = "DnsServiceRegister failed with code " + std::to_string(result);
    return false;
  }
  registration_ = std::move(registration);
  return true;
}

void MdnsAdvertiser::withdraw() {
  if (!registration_) return;
  Registration& r = *registration_;

  if (!r.waitDone()) {
    // Still registering: cancel it. If Windows never confirms, leak the registration
    // rather than free memory a late callback would write to.
    DnsServiceRegisterCancel(&r.cancel);
    if (!r.waitDone()) {
      (void)registration_.release();  // deliberately leaked, see above
      return;
    }
  } else if (r.status == ERROR_SUCCESS) {
    ResetEvent(r.done);
    if (DnsServiceDeRegister(&r.request, nullptr) == DNS_REQUEST_PENDING && !r.waitDone()) {
      (void)registration_.release();  // deliberately leaked, see above
      return;
    }
  }
  registration_.reset();
}

}  // namespace rmm
