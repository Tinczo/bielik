#pragma once

#include <algorithm>
#include <functional>
#include <string>
#include <utility>
#include <vector>

namespace rmm {

struct Track {
  std::string guid;  // REAPER track GUID, e.g. "{1B6A2C10-...}"
  std::string name;  // UTF-8, as typed in REAPER
};

// A receive of a track: audio coming from another track (REAPER send category -1).
struct Receive {
  std::string sourceGuid;  // GUID of the track the receive comes from
  double level = 1.0;      // receive volume (D_VOL), linear: 1.0 = 0 dB, 0 = -inf
};

// Port "REAPER project": the only way the monitors core sees the active project.
// Implemented by the real REAPER API adapter and by an in-memory fake in tests.
// Called on the main thread only.
class ReaperProject {
 public:
  // Called on the main thread when something in the active project may have changed:
  // tracks added/removed/moved/renamed, receives changed, receive levels changed,
  // another project became active. Spurious calls are allowed; listeners re-read the
  // project and compare with what they already know.
  using ChangeListener = std::function<void()>;

  virtual ~ReaperProject() = default;

  // All tracks of the active project, in project order.
  virtual std::vector<Track> tracks() const = 0;

  // Receives of the track with this GUID, in REAPER's receive order. Empty if the track
  // has none or does not exist.
  virtual std::vector<Receive> receives(const std::string& trackGuid) const = 0;

  // Listening does not change the project, hence const. Returns a handle for
  // removeChangeListener().
  int addChangeListener(ChangeListener listener) const {
    listeners_.emplace_back(++lastListenerId_, std::move(listener));
    return lastListenerId_;
  }
  void removeChangeListener(int handle) const {
    listeners_.erase(std::remove_if(listeners_.begin(), listeners_.end(),
                                    [handle](const auto& entry) { return entry.first == handle; }),
                     listeners_.end());
  }

 protected:
  // Implementations call this when they detect a (possible) change.
  void notifyChanged() const {
    const auto listeners = listeners_;  // a listener may add or remove listeners
    for (const auto& entry : listeners) entry.second();
  }

 private:
  mutable std::vector<std::pair<int, ChangeListener>> listeners_;
  mutable int lastListenerId_ = 0;
};

}  // namespace rmm
