# Troubleshooting

## The app looks like it did not open

MacFan is a menu bar utility. It keeps a fan icon in the menu bar and does not
show a Dock icon. Opening the app from Finder also opens the main control
window.

If the menu bar icon is hidden, check macOS menu bar settings and any menu bar
management apps you use.

Verify the app is running:

```sh
pgrep -fl MacFan
```

## The menu bar does not show RPM

This is intentional. The menu bar item shows only the fan icon. RPM is available
in the tooltip and inside the control panel/window.

## The app keeps asking for a password

MacFan should ask once when it installs its privileged helper. Check the helper:

```sh
ls -l /Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
/Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl doctor
```

Expected:

- owner is `root`
- group is `wheel`
- permissions include setuid: `-rwsr-xr-x`
- `doctor` prints `euid: 0`

If the helper is stale or has wrong permissions, remove it and try another fan
change from the app:

```sh
sudo rm -f /Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
```

## A fan does not change speed

Try these checks:

```sh
/Applications/MacFan.app/Contents/Helpers/macfanctl fans
sudo /Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl doctor
```

If SMC rejects the write, MacFan shows the SMC error. Some firmware revisions
can reject manual fan control even when the helper is running as root.

## Return control to macOS

Use All Auto in the app, or run:

```sh
/Applications/MacFan.app/Contents/Helpers/macfanctl reset
```

If you want to remove MacFan entirely:

```sh
pkill -x MacFan || true
sudo rm -rf /Applications/MacFan.app
sudo rm -f /Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
```
