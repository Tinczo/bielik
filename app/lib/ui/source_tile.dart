import 'dart:async';

import 'package:flutter/material.dart';

import '../protocol/messages.dart';
import 'level_curve.dart';
import 'level_format.dart';

/// One source of a monitor: its name, level in dB and a slider to set it.
///
/// While the musician drags, the new level is sent live but at most once per
/// [sendInterval]; the final value is always sent on release. A double tap
/// resets the level to 0 dB. While the slider is held, levels pushed by the
/// server ([source] changes) are not shown, so the slider does not jump under
/// the finger; after release it shows [source] again.
class SourceTile extends StatefulWidget {
  const SourceTile({super.key, required this.source, required this.onLevel});

  final Source source;

  /// Called with each level to send to the server.
  final ValueChanged<double> onLevel;

  /// About 25 messages per second while dragging.
  static const sendInterval = Duration(milliseconds: 40);

  @override
  State<SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends State<SourceTile> {
  double? _dragPosition;
  Timer? _throttle;
  double? _unsentLevel;

  double get _level => _dragPosition == null
      ? widget.source.level
      : levelFromPosition(_dragPosition!);

  void _sendThrottled(double level) {
    if (_throttle != null) {
      _unsentLevel = level;
      return;
    }
    widget.onLevel(level);
    _throttle = Timer(SourceTile.sendInterval, _sendUnsent);
  }

  void _sendUnsent() {
    _throttle = null;
    final level = _unsentLevel;
    if (level == null) return;
    _unsentLevel = null;
    _sendThrottled(level);
  }

  void _sendFinal(double level) {
    _throttle?.cancel();
    _throttle = null;
    _unsentLevel = null;
    widget.onLevel(level);
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return ListTile(
      title: Text(source.name),
      trailing: Text(formatLevelDb(_level)),
      subtitle: GestureDetector(
        onDoubleTap: () => _sendFinal(1.0),
        child: Slider(
          key: Key('level-${source.id}'),
          value: _dragPosition ?? positionFromLevel(source.level),
          onChangeStart: (position) => setState(() => _dragPosition = position),
          onChanged: (position) {
            setState(() => _dragPosition = position);
            _sendThrottled(levelFromPosition(position));
          },
          onChangeEnd: (position) {
            setState(() => _dragPosition = null);
            _sendFinal(levelFromPosition(position));
          },
        ),
      ),
    );
  }
}
