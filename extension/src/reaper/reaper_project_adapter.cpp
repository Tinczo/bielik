#include "reaper/reaper_project_adapter.h"

#include "reaper/reaper_api.h"

namespace rmm {

namespace {

constexpr ReaProject* kActiveProject = nullptr;
constexpr int kReceives = -1;  // send category of receives

std::string guidOf(MediaTrack* track) {
  char guid[64] = {};
  guidToString(GetTrackGUID(track), guid);
  return guid;
}

MediaTrack* findTrack(const std::string& guid) {
  const int count = CountTracks(kActiveProject);
  for (int i = 0; i < count; ++i) {
    MediaTrack* track = GetTrack(kActiveProject, i);
    if (track && guidOf(track) == guid) return track;
  }
  return nullptr;
}

}  // namespace

std::vector<Track> ReaperProjectAdapter::tracks() const {
  std::vector<Track> result;
  const int count = CountTracks(kActiveProject);
  result.reserve(count);
  for (int i = 0; i < count; ++i) {
    MediaTrack* track = GetTrack(kActiveProject, i);
    if (!track) continue;

    char name[4096] = {};
    GetSetMediaTrackInfo_String(track, "P_NAME", name, false);
    result.push_back({guidOf(track), name});
  }
  return result;
}

std::vector<Receive> ReaperProjectAdapter::receives(const std::string& trackGuid) const {
  std::vector<Receive> result;
  MediaTrack* track = findTrack(trackGuid);
  if (!track) return result;
  const int count = GetTrackNumSends(track, kReceives);
  for (int i = 0; i < count; ++i) {
    // For P_ parameters the returned pointer is the value itself.
    auto* source = static_cast<MediaTrack*>(GetSetTrackSendInfo(track, kReceives, i, "P_SRCTRACK", nullptr));
    if (!source) continue;
    result.push_back({guidOf(source), GetTrackSendInfo_Value(track, kReceives, i, "D_VOL")});
  }
  return result;
}

}  // namespace rmm
