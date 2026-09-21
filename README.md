# smart_iq

Smart IQ — General Knowledge & IQ exam preparation for Sri Lanka.

Flutter app targeting **Android and iOS**. The backend is Supabase; see
[supabase/README.md](supabase/README.md) for the schema, the Edge Functions and
the secrets they need.

## Running on Android

```
flutter pub get
flutter run
```

## Running on iOS

The iOS target is scaffolded and configured, but **it cannot be built on
Windows**. Xcode is the only toolchain that compiles and signs an iOS binary
and it is macOS-only. There is no workaround for this — not WSL, not a VM, not
a cross-compiler. What follows are the three real options.

### On a Mac

```
flutter pub get
cd ios && pod install && cd ..
flutter run
```

`pod install` reads [ios/Podfile](ios/Podfile), which pins the deployment
target to iOS 15.0. That floor comes from the plugins: `supabase_flutter`
needs iOS 13 and `flutter_secure_storage` needs iOS 12.

To install on a physical iPhone you also need a signing identity. A free
Apple ID works through Xcode — open `ios/Runner.xcworkspace`, pick your team
under Signing & Capabilities, and the app installs with a certificate that
expires after 7 days. A paid account ($99/year) removes the expiry.

### Via GitHub Actions, without a Mac

[.github/workflows/ios.yml](.github/workflows/ios.yml) builds on a macOS
runner. It runs on every push to `main` and can be triggered by hand from the
Actions tab.

The default job builds `--no-codesign`. That **verifies the iOS target
compiles and every plugin resolves**, which is the thing most likely to be
broken, and it is worth having. But an unsigned binary will not launch on a
device, so it does not by itself get the app onto your iPhone.

The commented-out `release` job does, via TestFlight. It needs a paid Apple
Developer account and four repository secrets, listed in the workflow file.
This is the only path that ends with the app on a real iPhone without owning
a Mac.

### On the iOS Simulator

The simulator is part of Xcode, so it is also macOS-only. A simulator build
would not exercise the OTP flow faithfully anyway — `flutter_secure_storage`
behaves differently against a simulator keychain.

## Branding assets

There is no iOS-specific UI. Flutter renders the same widget tree on both
platforms, so every screen, theme and font in `lib/` applies to iOS unchanged.
Only the platform chrome outside `lib/` is per-platform, and it is generated:

```
dart run flutter_launcher_icons
```

That reads `assets/images/app_icon.png` and writes both the Android
`mipmap-*` icons and the iOS `AppIcon.appiconset`.

`app_icon.png` is derived from `app_logo.png` and is not hand-drawn — the raw
logo is 459×475 with white arcs at its rounded corners, which show as white
slivers once a launcher applies its own mask. The derivation squares it, fills
those arcs by flood-filling inward from the border (a global white replace
would destroy the white book and "IQ" glyphs inside the art), zooms past the
logo's own rounding so it bleeds edge to edge, and drops the alpha channel
that iOS icons may not carry.

The cold-start screen is kept in step by hand across
`ios/Runner/Base.lproj/LaunchScreen.storyboard` and
`android/app/src/main/res/drawable-v21/launch_background.xml` — the same mark
centred on the same `#17345E`. Note that `drawable-v21/` is the file that
matters; the `drawable/` copy is only the pre-API-21 fallback.

## Platform differences worth knowing

`device_id` ([lib/data/auth/session_store.dart](lib/data/auth/session_store.dart))
is a random value held in `flutter_secure_storage`. On iOS that is the
Keychain, whose entries **survive app uninstall**; Android's encrypted
preferences do not. So reinstalling on iOS rotates the existing
`auth_sessions` row, while on Android it creates a second entry in the user's
device list.

## Tests

```
flutter analyze
flutter test
```
