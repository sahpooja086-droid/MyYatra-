import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// How long the app can sit untouched before the user is signed out.
/// Change this one value to make the timeout shorter or longer.
const Duration defaultIdleTimeout = Duration(minutes: 10);

/// Wraps a signed-in screen and calls [onTimeout] once nobody has touched
/// the app for [timeout].
///
/// Every touch, drag or scroll anywhere in the app counts as activity and
/// restarts the countdown, including on screens opened on top of [child].
/// Time spent with the app in the background also counts as idle time.
class IdleTimeoutGate extends StatefulWidget {
  const IdleTimeoutGate({
    super.key,
    required this.child,
    required this.onTimeout,
    this.timeout = defaultIdleTimeout,
  });

  final Widget child;
  final VoidCallback onTimeout;
  final Duration timeout;

  @override
  State<IdleTimeoutGate> createState() => _IdleTimeoutGateState();
}

class _IdleTimeoutGateState extends State<IdleTimeoutGate>
    with WidgetsBindingObserver {
  static const Duration _tick = Duration(seconds: 1);

  Timer? _ticker;
  Duration _idleFor = Duration.zero;
  DateTime? _backgroundedAt;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    _startTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tick, (_) => _addIdleTime(_tick));
  }

  void _addIdleTime(Duration extra) {
    if (_timedOut) return;
    _idleFor += extra;
    if (_idleFor >= widget.timeout) {
      _timedOut = true;
      _ticker?.cancel();
      widget.onTimeout();
    }
  }

  void _onPointerEvent(PointerEvent event) {
    if (!_timedOut) _idleFor = Duration.zero;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_timedOut) return;
    if (state == AppLifecycleState.paused) {
      // Timers can stop while the app is in the background, so remember when
      // it left and work out the missing time when it comes back.
      _backgroundedAt = DateTime.now();
      _ticker?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null) {
        _addIdleTime(DateTime.now().difference(since));
      }
      if (!_timedOut) _startTicker();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
