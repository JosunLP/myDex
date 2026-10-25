# 0001 – Flutter und Dart als gemeinsame Client-Codebase

Status: angenommen

## Kontext
Zielplattformen sind Android (inkl. GrapheneOS ohne Play Services), iOS, Windows, macOS und Linux.

## Entscheidung
Flutter und Dart, Riverpod für Zustand/DI, go_router für Navigation. Fachlogik in reinen
Dart-Paketen ohne Flutter-Abhängigkeit. Keine zusätzliche Rust-Schicht ohne gemessenen Bedarf.

## Konsequenzen
- Plattformspezifisch bleiben Signierung, Paketierung, Dateidialoge, TTS, sichere Ablage.
- iOS/macOS-Builds benötigen macOS-Runner.
- Fachlogik ist mit `dart test` ohne Gerät testbar.
