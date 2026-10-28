# 0001 – Flutter and Dart as the shared client codebase

Status: accepted

## Context
Target platforms are Android (including GrapheneOS without Play Services), iOS, Windows, macOS
and Linux.

## Decision
Flutter and Dart, Riverpod for state/DI, go_router for navigation. Domain logic in pure Dart
packages without a Flutter dependency. No additional Rust layer without a measured need.

## Consequences
- Signing, packaging, file dialogs, TTS and secure storage stay platform-specific.
- iOS/macOS builds need macOS runners.
- Domain logic can be tested with `dart test` without a device.
