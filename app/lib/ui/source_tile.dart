import 'dart:async';

import 'package:flutter/material.dart';

import '../protocol/messages.dart';
import 'level_curve.dart';
import 'level_format.dart';

/// One source of a monitor: its name, level in dB and a slider to set it.
///
/// While the musician drags, the new level is sent live but at most once per
/// [sendInterval]; the final value is always sent on release. A double tap
/// resets the level to 0 dB. A disabled tile (e.g. while disconnected) only
/// shows the level.
class SourceTile extends StatefulWidget {
  const SourceTile({
    super.key,
    required this.source,
    required this.onLevel,
    this.enabled = true,
  });

  final Source source;

  /// Whether the musician can change the level now.
  final bool enabled;

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
  void didUpdateWidget(SourceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      // A drag cut short by a disconnect: nothing more can be sent.
      _throttle?.cancel();
      _throttle = null;
      _unsentLevel = null;
      _dragPosition = null;
    }
  }

  @override
  void dispose() {
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final enabled = widget.enabled;
    return ListTile(
      enabled: enabled,
      title: Text(source.name),
      trailing: Text(formatLevelDb(_level)),
      subtitle: GestureDetector(
        onDoubleTap: enabled ? () => _sendFinal(1.0) : null,
        child: Slider(
          key: Key('level-${source.id}'),
          value: _dragPosition ?? positionFromLevel(source.level),
          onChangeStart: enabled
              ? (position) => setState(() => _dragPosition = position)
              : null,
          onChanged: enabled
              ? (position) {
                  setState(() => _dragPosition = position);
                  _sendThrottled(levelFromPosition(position));
                }
              : null,
          onChangeEnd: enabled
              ? (position) {
                  setState(() => _dragPosition = null);
                  _sendFinal(levelFromPosition(position));
                }
              : null,
        ),
      ),
    );
  }
}
