# MacFan

MacFan is a small macOS menu bar app for reading and controlling SMC fan speeds.

The first version follows the shape used by [exelban/stats](https://github.com/exelban/stats): fan data comes from SMC keys such as `FNum`, `F0Ac`, `F0Mn`, `F0Mx`, `F0Tg`, and mode keys such as `F0Md` or `F0md`.

## Run

```sh
./script/build_and_run.sh
```

The app runs as a menu-bar-only utility. Use the fan icon in the menu bar to refresh, switch a fan between automatic and manual mode, apply a target RPM, or reset all fans to automatic mode.

Changing fan control installs the bundled `macfanctl` helper once at `/Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl` through macOS' administrator prompt. Reads stay in the menu app; writes run through the installed helper so SMC accepts them on systems that require privileged access.

The build script signs `dist/MacFan.app` and its bundled helper with the first available `Apple Development:` code signing identity. Set `MACFAN_CODESIGN_IDENTITY` to override that choice.

## Notes

- On macOS 26 and newer, System Settings can hide menu bar items until the app is allowed under System Settings > Menu Bar.
- Some firmware can still reject manual control even when the helper is running as root. When that happens, MacFan shows the SMC error in the menu.
- `macfanctl` can also be run directly from the bundle at `dist/MacFan.app/Contents/Helpers/macfanctl`.
- If helper installation succeeds, later fan changes should not repeatedly ask for the administrator password.
- Apple Development signing is valid for local development. Sharing the app outside your machine still requires a Developer ID/notarization or App Store distribution flow.
- Use conservative fan speeds. Hardware and firmware protections still apply, but manual fan control can increase noise, wear, or heat if misused.
