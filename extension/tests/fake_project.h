#pragma once

#include <map>
#include <string>
#include <vector>

#include "core/reaper_project.h"

namespace rmm::testing {

// In-memory REAPER project. Tests edit `trackList` and `receiveLists` directly, then call
// changed() like the real adapter does when REAPER reports a change.
class FakeProject : public ReaperProject {
 public:
  std::vector<Track> trackList;
  std::map<std::string, std::vector<Receive>> receiveLists;  // by track GUID

  std::vector<Track> tracks() const override { return trackList; }

  std::vector<Receive> receives(const std::string& trackGuid) const override {
    const auto found = receiveLists.find(trackGuid);
    return found == receiveLists.end() ? std::vector<Receive>{} : found->second;
  }

  void changed() const { notifyChanged(); }
};

}  // namespace rmm::testing
