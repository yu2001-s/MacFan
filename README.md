# MacFan

MacFan is a small macOS menu bar app for reading and controlling Mac fan speeds.
It provides per-fan sliders, Auto and Max controls, group controls, and a
bundled command-line helper for SMC writes.

The SMC access layer follows the shape used by
[exelban/stats](https://github.com/exelban/stats), including fan keys such as
`FNum`, `F0Ac`, `F0Mn`, `F0Mx`, `F0Tg`, and mode keys such as `F0Md` or
`F0md`.

## Features

- Menu bar fan icon with the current fan state in the tooltip.
- Floating control panel plus a normal control window when the app is opened.
- Per-fan Auto and Max buttons.
- All Auto and All Max group controls.
- Continuous sliders that apply after a short debounce; no separate Apply step.
- Privileged helper for fan writes, installed only when a write is needed.
- `macfanctl` CLI for listing fans, setting RPM, setting mode, and reset.
- Local Raycast extension for controlling fans from Raycast.

## Requirements

- macOS 14 or newer.
- A Mac that exposes fan control through AppleSMC keys.
- Administrator password the first time MacFan installs its helper.
- Xcode command line tools if building from source.

## Install

Download the latest `MacFan-<version>-macos.zip` from GitHub Releases, unzip it,
and move `MacFan.app` to `/Applications`.

Public release artifacts are development/ad-hoc signed unless a Developer ID
certificate and notarization are configured. If Gatekeeper blocks a downloaded
build, build from source locally or see [Install](docs/INSTALL.md) for the exact
macOS prompts and safer verification commands.

To build and install from source:

```sh
git clone https://github.com/yu2001-s/MacFan.git
cd MacFan
./script/install_app.sh
```

To build and run without installing:

```sh
./script/build_and_run.sh
```

To create a release zip locally:

```sh
./script/package_release.sh
```

## Controls

- Drag a fan slider to set that fan's target RPM. The change applies
  automatically after a short pause.
- Auto returns that fan to system control.
- Max sets that fan to its firmware-reported maximum RPM.
- All Auto returns every fan to system control.
- All Max sets every fan to its own firmware-reported maximum RPM.
- Refresh reloads the SMC fan state.
- Window opens the larger control window.

The menu bar item intentionally shows only the fan icon. RPM is shown in the
tooltip and control UI.

## CLI

The bundled helper can also be used directly:

```sh
MacFan.app/Contents/Helpers/macfanctl fans
MacFan.app/Contents/Helpers/macfanctl fans --json
MacFan.app/Contents/Helpers/macfanctl set-speed --id 0 --rpm 3000
MacFan.app/Contents/Helpers/macfanctl set-mode --id 0 --mode auto
MacFan.app/Contents/Helpers/macfanctl reset
```

When used from the app, writes run through the installed privileged helper at:

```text
/Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
```

## Raycast

A local Raycast extension is available in [raycast-macfan](raycast-macfan).
It exposes `Control Fans`, `Auto Fan`, and `Max Fan` commands.

```sh
cd raycast-macfan
npm install
npm run dev
```

## Documentation

- [Install](docs/INSTALL.md)
- [Development](docs/DEVELOPMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Security notes](docs/SECURITY.md)
- [Third party notices](THIRD_PARTY_NOTICES.md)

## Safety

Manual fan control can affect temperature, noise, and fan wear. Hardware and
firmware protections still apply, but use conservative values and return to Auto
when you no longer need manual control.

## License

MacFan is released under the MIT License. See [LICENSE](LICENSE).
