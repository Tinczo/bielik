#pragma once

#include <map>
#include <string>
#include <vector>

#include "core/reaper_project.h"

namespace rmm::testing {

// In-memory REAPER project. Tests edit `trackList` and `receiveLists` directly and read
// the levels the server wrote from `levelWrites`.
class FakeProject : public ReaperProject {
 public:
  std::vector<Track> trackList;
  std::map<std::string, std::vector<Receive>> receiveLists;  // by track GUID

  // Every successful setReceiveLevel call, in order.
  struct LevelWrite {
    std::string trackGuid;
    std::string sourceGuid;
    double level;
  };
  std::vector<LevelWrite> levelWrites;

  std::vector<Track> tracks() const override { return trackList; }

  std::vector<Receive> receives(const std::string& trackGuid) const override {
    const auto found = receiveLists.find(trackGuid);
    return found == receiveLists.end() ? std::vector<Receive>{} : found->second;
  }

  bool setReceiveLevel(const std::string& trackGuid, const std::string& sourceGuid,
                       double level) override {
    for (Receive& receive : receiveLists[trackGuid]) {
      if (receive.sourceGuid == sourceGuid) {
        receive.level = level;
        levelWrites.push_back({trackGuid, sourceGuid, level});
        return true;
      }
    }
    return false;
  }
};

}  // namespace rmm::testing
