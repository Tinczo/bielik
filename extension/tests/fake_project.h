#pragma once

#include <map>
#include <string>
#include <vector>

#include "core/reaper_project.h"

namespace rmm::testing {

// In-memory REAPER project. Tests edit `trackList` and `receiveLists` directly, then call
// changed() like the real adapter does when REAPER reports a change. Levels the server
// wrote are in `levelWrites`; like REAPER reporting a receive volume change, each write
// also notifies the change listeners, unless `notifiesOwnWrites` is false.
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

  std::map<std::string, std::vector<HardwareSend>> hardwareSendLists;  // by track GUID

  // Every successful setHardwareSendLevel call, in order.
  struct HardwareSendWrite {
    std::string trackGuid;
    int index;
    double level;
  };
  std::vector<HardwareSendWrite> hardwareSendWrites;
  bool notifiesOwnWrites = true;

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
        if (notifiesOwnWrites) notifyChanged();
        return true;
      }
    }
    return false;
  }

  std::vector<HardwareSend> hardwareSends(const std::string& trackGuid) const override {
    const auto found = hardwareSendLists.find(trackGuid);
    return found == hardwareSendLists.end() ? std::vector<HardwareSend>{} : found->second;
  }

  bool setHardwareSendLevel(const std::string& trackGuid, int index, double level) override {
    auto& sends = hardwareSendLists[trackGuid];
    if (index < 0 || index >= static_cast<int>(sends.size())) return false;
    sends[index].level = level;
    hardwareSendWrites.push_back({trackGuid, index, level});
    if (notifiesOwnWrites) notifyChanged();
    return true;
  }

  void changed() const { notifyChanged(); }
};

}  // namespace rmm::testing
