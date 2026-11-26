import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/motion.dart';

/// Marks the start of a staggered entrance (e.g. a list after a search or a
/// game switch). Give it a new [key] to replay the entrance.
///
/// Only items built shortly after the start animate: items that appear later
/// while scrolling show up instantly, so scrolling never feels sluggish.
class EntranceScope extends StatefulWidget {
  const EntranceScope({super.key, required this.child});

  final Widget child;

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  late final Duration _start = _now();

  static Duration _now() => SchedulerBinding.instance.currentFrameTimeStamp;

  @override
  Widget build(BuildContext context) =>
      _EntranceData(start: _start, child: widget.child);
}

class _EntranceData extends InheritedWidget {
  const _EntranceData({required this.start, required super.child});

  final Duration start;

  /// Window in which newly built items still take part in the entrance.
  static const window = Duration(milliseconds: 350);

  bool get active =>
      SchedulerBinding.instance.currentFrameTimeStamp - start < window;

  @override
  bool updateShouldNotify(_EntranceData old) => old.start != start;
}

/// Fades and slides an item in, delayed by its [index] (staggered).
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.index,
    required this.child,
    this.offset = 18,
    this.axis = Axis.vertical,
  });

  final int index;
  final Widget child;

  /// Distance in logical pixels the item travels.
  final double offset;
  final Axis axis;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _curve;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final scope = context.getInheritedWidgetOfExactType<_EntranceData>();
    final animate = scope != null && scope.active && !Motion.reduced(context);
    if (!animate) return;
    final delay = Motion.stagger * widget.index.clamp(0, 10);
    final total = delay + Motion.long;
    final controller = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Motion.enter,
      ),
    );
    _controller = controller..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final t = _curve.value;
        if (t >= 1) return child!;
        final shift = (1 - t) * widget.offset;
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: widget.axis == Axis.vertical
                ? Offset(0, shift)
                : Offset(shift, 0),
            child: child,
          ),
        );
      },
    );
  }
}

/// Cross-fades between children with a subtle zoom ("fade through"): for
/// content that is replaced, e.g. after switching the game.
class FadeThroughSwitcher extends StatelessWidget {
  const FadeThroughSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.of(context, Motion.medium),
    switchInCurve: Motion.enter,
    switchOutCurve: Motion.exit,
    layoutBuilder: (current, previous) =>
        Stack(alignment: alignment, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.97, end: 1.0).animate(animation),
        alignment: alignment,
        child: child,
      ),
    ),
    child: child,
  );
}

/// Plays a short "pop" (scale overshoot) whenever [active] turns true –
/// confirmation for marking a Pokémon as caught.
class PopOnActivate extends StatefulWidget {
  const PopOnActivate({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<PopOnActivate> createState() => _PopOnActivateState();
}

class _PopOnActivateState extends State<PopOnActivate>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.long,
  );
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.32,
      ).chain(CurveTween(curve: Motion.enter)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.32,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(PopOnActivate old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !Motion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Scales its child down slightly while pressed: tactile feedback for cards.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: Motion.of(context, Motion.short),
      curve: Motion.standard,
      child: widget.child,
    ),
  );
}

/// A number that counts up to [value] (progress, totals).
class CountUpText extends StatelessWidget {
  const CountUpText(this.value, {super.key, this.style, this.format});

  final int value;
  final TextStyle? style;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: Motion.of(context, Motion.reveal),
    curve: Motion.enter,
    builder: (context, v, _) {
      final n = v.round();
      return Text(format?.call(n) ?? '$n', style: style);
    },
  );
}
