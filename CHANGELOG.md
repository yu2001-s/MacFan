# Changelog

## 0.3.0

- Added `macfanctl temps` for CPU, GPU, and peak die temperatures.
- Added `macfanctl smart`, a temperature-driven fan curve with Quiet, Balanced,
  and Cool profiles that hands the fans back to macOS when the Mac is cool or
  when it stops.
- Moved the Raycast extension out of this repository into a separate Toolbox
  extension.

## 0.2.1

- Added a local Raycast extension with commands for viewing fans, custom RPM,
  per-fan Auto/Manual/Max, All Auto, and All Max.
- Added GitHub/Raycast distribution documentation.
- Improved the Raycast extension error state when the privileged helper is not
  installed yet.

## 0.2.0

- Added a menu bar fan controller with per-fan Auto and Max controls.
- Added All Auto and All Max group controls.
- Added slider auto-apply behavior with per-fan debouncing.
- Added a privileged helper path for SMC fan writes.
- Added `macfanctl` for fan listing, manual RPM targets, mode changes, reset,
  and helper diagnostics.
- Added launch/reopen behavior that shows the control window while keeping the
  menu bar icon.
- Added release packaging and public installation documentation.
