# Development

## Requirements

- macOS 14 or newer.
- Swift 5.9 or newer.
- Xcode command line tools.
- Optional Apple Development or Developer ID certificate for signing.

Install Xcode command line tools:

```sh
xcode-select --install
```

## Build and run

```sh
./script/build_and_run.sh
```

This script:

1. Builds `MacFan`.
2. Builds `macfanctl`.
3. Creates `dist/MacFan.app`.
4. Copies `macfanctl` into `Contents/Helpers`.
5. Signs the helper and app.
6. Opens the app.

Run verification without leaving the app open:

```sh
./script/build_and_run.sh --verify
```

Build the app bundle without launching it:

```sh
./script/build_and_run.sh --build-only
```

## Install locally

```sh
./script/install_app.sh
```

This builds the app, copies it to `/Applications/MacFan.app`, and opens it.

## Package a release zip

```sh
./script/package_release.sh
```

The script writes:

```text
artifacts/MacFan-0.2.0-macos.zip
artifacts/MacFan-0.2.0-macos.zip.sha256
```

Use a custom version:

```sh
./script/package_release.sh 0.2.1
```

## Signing

By default, the build script uses the first local `Apple Development:`
certificate found by `security find-identity -p codesigning -v`.

Override the identity:

```sh
MACFAN_CODESIGN_IDENTITY="Apple Development: Name (TEAMID)" ./script/build_and_run.sh
```

Force ad-hoc signing:

```sh
MACFAN_CODESIGN_IDENTITY="-" ./script/package_release.sh
```

Ad-hoc and Apple Development signatures are useful for local builds and CI
artifacts, but they are not enough for a smooth public download experience.
Outside the Mac App Store, public distribution normally requires a Developer ID
Application certificate, hardened runtime settings, and Apple notarization.

## GitHub Actions

`.github/workflows/build.yml` builds and packages the app on macOS using ad-hoc
signing. The uploaded artifact is intended for testing. Treat it as a CI build,
not a notarized public distribution build.
