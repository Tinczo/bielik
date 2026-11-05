#include "reaper/reaper_project_adapter.h"

#include "reaper/reaper_api.h"

namespace rmm {

namespace {

constexpr ReaProject* kActiveProject = nullptr;
constexpr int kReceives = -1;  // send category of receives
constexpr int kHardwareSends = 1;  // send category of hardware outputs

std::string guidOf(MediaTrack* track) {
  char guid[64] = {};
  guidToString(GetTrackGUID(track), guid);
  return guid;
}

// The track a receive comes from. For P_ parameters the returned pointer is the value itself.
MediaTrack* receiveSource(MediaTrack* track, int receive) {
  return static_cast<MediaTrack*>(
      GetSetTrackSendInfo(track, kReceives, receive, "P_SRCTRACK", nullptr));
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

// Hidden control surface (not listed in REAPER's preferences): REAPER calls it on the main
// thread whenever the state a surface would mirror changes.
class ReaperProjectAdapter::ChangeSurface : public IReaperControlSurface {
 public:
  explicit ChangeSurface(ReaperProjectAdapter& adapter) : adapter_(adapter) {}

  const char* GetTypeString() override { return "RMMCHANGES"; }
  const char* GetDescString() override { return "reaper_mobile_mixer change detection"; }
  const char* GetConfigString() override { return ""; }

  // Also called when another project tab becomes active.
  void SetTrackListChange() override { adapter_.markDirty(); }
  void SetTrackTitle(MediaTrack*, const char*) override { adapter_.markDirty(); }

  int Extended(int call, void*, void*, void*) override {
    switch (call) {
      case CSURF_EXT_RESET:
      case CSURF_EXT_SETRECVVOLUME:
      case CSURF_EXT_SETSENDVOLUME:  // a send of the source track is a receive of a monitor
        adapter_.markDirty();
        break;
      default:
        break;
    }
    return 0;
  }

 private:
  ReaperProjectAdapter& adapter_;
};

ReaperProjectAdapter::ReaperProjectAdapter() : surface_(std::make_unique<ChangeSurface>(*this)) {}

ReaperProjectAdapter::~ReaperProjectAdapter() = default;

IReaperControlSurface* ReaperProjectAdapter::controlSurface() { return surface_.get(); }

void ReaperProjectAdapter::poll() {
  ReaProject* project = EnumProjects(-1, nullptr, 0);  // the active project
  const int stateCount = GetProjectStateChangeCount(project);
  if (project != lastProject_ || stateCount != lastStateCount_) dirty_ = true;
  lastProject_ = project;
  lastStateCount_ = stateCount;
  if (!dirty_) return;
  dirty_ = false;
  notifyChanged();
}

std::vector<Track> ReaperProjectAdapter::tracks() const {
  std::vector<Track> result;
  const int count = CountTracks(kActiveProject);
  result.reserve(count);
  for (int i = 0; i < count; ++i) {
    MediaTrack* track = GetTrack(kActiveProject, i);
    if (!track) continue;

    // The name REAPER displays: an unnamed track reads "Track N", which never carries the
    // monitor prefix, while a named track gives exactly what was typed.
    char name[4096] = {};
    GetTrackName(track, name, sizeof(name));
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
    MediaTrack* source = receiveSource(track, i);
    if (!source) continue;
    result.push_back({guidOf(source), GetTrackSendInfo_Value(track, kReceives, i, "D_VOL")});
  }
  return result;
}

bool ReaperProjectAdapter::setReceiveLevel(const std::string& trackGuid,
                                           const std::string& sourceGuid, double level) {
  MediaTrack* track = findTrack(trackGuid);
  if (!track) return false;
  const int count = GetTrackNumSends(track, kReceives);
  for (int i = 0; i < count; ++i) {
    MediaTrack* source = receiveSource(track, i);
    if (!source || guidOf(source) != sourceGuid) continue;
    // Written like a control-surface fader move, not with SetTrackSendInfo_Value: the
    // mixer UI follows the change. SetTrackSendUIVol over CSurf_OnRecvVolumeChange because
    // REAPER's own web remote (csurf_www.cpp) uses it for exactly this, and its `isend`
    // argument lets us say "tweak in progress" (0) explicitly: the wire has no
    // end-of-gesture, so we never send "end of edit" (1), which is what adds an undo point.
    // A negative index addresses receives: -1 is the first one.
    constexpr int kTweak = 0;
    if (!SetTrackSendUIVol(track, -1 - i, level, kTweak)) return false;
    // A tweak alone may not mark the project as changed, and a mix set from the phones must
    // not be lost on close. This asks for a save prompt without adding an undo point.
    MarkProjectDirty(kActiveProject);
    return true;
  }
  return false;
}

std::vector<HardwareSend> ReaperProjectAdapter::hardwareSends(const std::string& trackGuid) const {
  std::vector<HardwareSend> result;
  MediaTrack* track = findTrack(trackGuid);
  if (!track) return result;
  const int count = GetTrackNumSends(track, kHardwareSends);
  for (int i = 0; i < count; ++i) {
    result.push_back({GetTrackSendInfo_Value(track, kHardwareSends, i, "D_VOL")});
  }
  return result;
}

bool ReaperProjectAdapter::setHardwareSendLevel(const std::string& trackGuid, int index,
                                                double level) {
  MediaTrack* track = findTrack(trackGuid);
  if (!track || index < 0 || index >= GetTrackNumSends(track, kHardwareSends)) return false;
  // SetTrackSendUIVol addresses receives and sends only; hardware outputs are written
  // through their D_VOL, which adds no undo point either. Marked dirty like receive
  // writes, so a mix set from the phones is not lost on close.
  if (!SetTrackSendInfo_Value(track, kHardwareSends, index, "D_VOL", level)) return false;
  MarkProjectDirty(kActiveProject);
  return true;
}

}  // namespace rmm
