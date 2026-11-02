#pragma once

#include <string>
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
  virtual ~ReaperProject() = default;

  // All tracks of the active project, in project order.
  virtual std::vector<Track> tracks() const = 0;

  // Receives of the track with this GUID, in REAPER's receive order. Empty if the track
  // has none or does not exist.
  virtual std::vector<Receive> receives(const std::string& trackGuid) const = 0;

  // Sets the volume (linear, as Receive::level) of the track's first receive coming from
  // the source track, the way a control surface would. Returns false if there is none.
  virtual bool setReceiveLevel(const std::string& trackGuid, const std::string& sourceGuid,
                               double level) = 0;
};

}  // namespace rmm
