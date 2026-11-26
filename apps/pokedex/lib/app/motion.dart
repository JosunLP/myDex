import 'package:flutter/material.dart';

/// Motion tokens of the design system (Material 3 easing and durations).
///
/// Every animation in the app is finite and respects "reduce motion"
/// (system setting or app setting): then durations collapse to zero and
/// the UI changes instantly.
abstract final class Motion {
  /// Small state changes: toggles, colours, icons.
  static const short = Duration(milliseconds: 160);

  /// Most transitions: cards, switchers, sheets.
  static const medium = Duration(milliseconds: 300);

  /// Large, expressive transitions: hero headers, entrances.
  static const long = Duration(milliseconds: 500);

  /// Values that grow (stat bars, progress) – slow enough to be read.
  static const reveal = Duration(milliseconds: 800);

  /// Delay between items of a staggered entrance.
  static const stagger = Duration(milliseconds: 35);

  /// Things that enter the screen.
  static const enter = Easing.emphasizedDecelerate;

  /// Things that leave the screen.
  static const exit = Easing.emphasizedAccelerate;

  /// Things that change in place.
  static const standard = Easing.standard;

  /// A small overshoot for playful confirmations (caught!).
  static const pop = Curves.easeOutBack;

  /// Whether animations are switched off (system or app setting).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
