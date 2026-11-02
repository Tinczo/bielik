#include "reaper/reaper_project_adapter.h"

#include "reaper/reaper_api.h"

namespace rmm {

namespace {
constexpr ReaProject* kActiveProject = nullptr;
}

std::vector<Track> ReaperProjectAdapter::tracks() const {
  std::vector<Track> result;
  const int count = CountTracks(kActiveProject);
  result.reserve(count);
  for (int i = 0; i < count; ++i) {
    MediaTrack* track = GetTrack(kActiveProject, i);
    if (!track) continue;

    char guid[64] = {};
    guidToString(GetTrackGUID(track), guid);
    char name[4096] = {};
    GetSetMediaTrackInfo_String(track, "P_NAME", name, false);
    result.push_back({guid, name});
  }
  return result;
}

}  // namespace rmm
