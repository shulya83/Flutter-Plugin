# Windows Text Overlay Demo

Flutter Windows demo for native text input detection and overlay rendering.

## What It Shows

- Flutter desktop shell with a native C++ Windows layer.
- Win32 focus/event tracking through `SetWinEventHook`.
- UI Automation focused-element inspection.
- Native topmost overlay rendering near the focused text field.
- Dart/native communication through method and event channels.
- Live app, control, geometry, text, and latency status in Flutter.

## Build

```powershell
$flutter="$env:USERPROFILE\develop\flutter\bin\flutter.bat"
& $flutter test
& $flutter build windows
```
