# SlapBack

A macOS menu bar app that detects physical slaps on your MacBook and responds with sounds, screen effects, haptic feedback, and combo tracking.

SlapBack reads your MacBook's built-in accelerometer to detect impacts near the trackpad, classifies them by intensity (Light / Medium / Hard / Extreme), and triggers configurable audio-visual feedback in real time.

## Requirements

- macOS 14.0+
- MacBook with built-in accelerometer (Apple Silicon)
- Xcode 17.0+ (to build from source)

## Building

```bash
# Debug build
cd SlapBack
./build.sh debug

# Release build (also creates a DMG installer)
./build.sh release

# Run
open build/SlapBack.app
```

Or open `SlapBack/SlapBack.xcodeproj` in Xcode and build directly.

## How It Works

SlapBack uses the MacBook's `AppleSPUHIDDevice` accelerometer sensor via IOKit HID. Raw sensor data is processed through an STA/LTA (Short-Term Average / Long-Term Average) ratio algorithm — the same technique used in seismology to detect earthquakes — to distinguish intentional slaps from normal laptop movement.

The detection pipeline:

1. **AccelerometerReader** reads raw HID reports at ~125Hz, decimated to ~15Hz
2. **SlapDetector** runs STA/LTA analysis with arming logic to prevent double-triggers
3. **SlapEngine** orchestrates all feedback systems when a slap is confirmed
4. **ComboTracker** tracks consecutive hits within a 2-second window

## Features

### Sound Packs
- **Bundled** — 7 pre-loaded packs: punch, gentleman, goat, fart, male, sexy, yamete
- **Speech** — Text-to-speech reactions that vary by intensity and combo tier
- **System Sounds** — macOS built-in alert sounds mapped to intensity levels
- **Custom** — Import your own audio files organized by intensity, or import `.zip` sound packs

### Visual Effects
- **Screen Flash** — Colored border flash scaled by intensity (yellow to red)
- **Confetti** — Particle animation on hard hits and high combos (all monitors)
- **Screen Shake** — Window shake on extreme impacts

### Combo System
- Consecutive hits within 2 seconds build combos: Double, Triple, Mega, Ultra, GODLIKE
- Optional combo announcer plays tier voice clips on combo tier changes
- Haptic combo patterns via Force Touch trackpad

### Challenges
Timed challenges with preset goals:
- **Warmup** — 10 slaps in 30 seconds
- **Speed Demon** — 20 slaps in 15 seconds
- **Combo King** — Hit a 5x combo in 60 seconds
- **Lightning** — 30 slaps in 10 seconds
- **Berserker** — 50 slaps in 60 seconds
- **Combo Master** — Hit a 10x combo in 120 seconds

### Beatbox Mode
Record a rhythm of slaps, then loop it back as a beat pattern.

### Automation
Run custom scripts on every slap detection:
- Shell scripts (`.sh`) — receives intensity as argument and environment variables
- AppleScript (`.scpt`, `.applescript`)
- Shortcuts (`.shortcut`)

Environment variables passed to shell scripts:
- `SLAPBACK_INTENSITY` — Light, Medium, Hard, or Extreme
- `SLAPBACK_INTENSITY_RAW` — 1, 2, 3, or 4

### Other
- **Global hotkey** — Ctrl+Shift+S to toggle detection
- **Focus/DND awareness** — automatically mutes all feedback when macOS Focus mode is active
- **Audio ducking** — briefly lowers system volume during slap playback
- **Idle taunts** — text-to-speech taunting after a configurable period of inactivity
- **USB monitoring** — optional sound on device connect/disconnect
- **Haptic feedback** — Force Touch trackpad feedback with optional morse-style patterns
- **Gesture detection** — recognizes single, double, and triple tap patterns
- **Auto-calibration** — learns your slapping pattern to tune sensitivity
- **Launch at login** — via macOS LoginItems
- **Statistics** — session and all-time tracking with milestone notifications
- **Keychain backup** — backup/restore all settings securely
- **Debug visualizer** — real-time accelerometer graphs with STA/LTA ratio display

## Settings

SlapBack lives in the menu bar. Click the hand icon to access quick controls, or open the full Settings window with 6 tabs:

| Tab | What it configures |
|-----|-------------------|
| **General** | Sensitivity, cooldown, auto-calibrate, gesture detection, Focus awareness, launch at login |
| **Sound** | Volume, dynamic volume, sound pack selection, bundled pack/file picker, custom sound import |
| **Effects** | Screen flash, confetti, screen shake, combo announcer, audio ducking, haptics, idle taunts, notifications |
| **Fun** | Slap challenges, beatbox mode, debug accelerometer visualizer |
| **Stats** | Session and all-time statistics, export, reset |
| **Advanced** | USB sounds, slap actions (scripting), sound recording, keychain backup/restore |

## Architecture

```
SlapBackApp.swift          App entry point, menu bar setup, onboarding
SlapEngine.swift           Central orchestrator — wires all subsystems together
SlapDetector.swift         STA/LTA impact detection algorithm
AccelerometerReader.swift  IOKit HID accelerometer interface

SoundPlayer.swift          Audio playback (bundled, speech, system, custom)
SoundRecorder.swift        Microphone recording for custom sounds
SoundPackImporter.swift    .zip sound pack import

ScreenFlash.swift          Border flash effect (all screens)
ScreenShake.swift          Window shake effect
ConfettiView.swift         Particle confetti animation (all screens)
HapticManager.swift        Force Touch trackpad haptics

ComboTracker.swift         Combo counting and tier calculation
GestureDetector.swift      Tap pattern recognition
SlapStats.swift            Statistics tracking with notifications
SlapChallenge.swift        Timed challenge system
BeatboxMode.swift          Rhythm recording and looped playback
SlapActions.swift          Custom script execution
IdleTaunts.swift           Inactivity speech taunts

MenuBarView.swift          Menu bar dropdown UI
SettingsView.swift         Settings window (6 tabs)
SettingsStore.swift        @AppStorage persistence + engine sync
OnboardingView.swift       First-launch setup wizard
CalibrationView.swift      Guided sensitivity calibration
DebugVisualizerView.swift  Real-time accelerometer graphs

WindowManager.swift        Centralized window lifecycle management
FocusMonitor.swift         macOS Focus/DND state monitoring
USBMonitor.swift           USB device connect/disconnect events
GlobalHotkey.swift         Ctrl+Shift+S hotkey via Carbon
KeychainStore.swift        Secure settings backup in Keychain
```

## License

[MIT License](LICENSE)
