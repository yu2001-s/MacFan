# Install

## Option 1: Download a release

1. Download `MacFan-<version>-macos.zip` from the latest GitHub Release.
2. Unzip it.
3. Move `MacFan.app` to `/Applications`.
4. Open `MacFan.app`.

MacFan opens a control window and also adds a fan icon to the menu bar. If you
close the window, the menu bar item remains available.

## Gatekeeper

Public artifacts from this repository are development/ad-hoc signed unless a
Developer ID certificate and notarization are configured by the maintainer.
macOS may show an "unidentified developer" or "cannot be opened" warning for a
downloaded build.

Prefer building from source on your own Mac if Gatekeeper blocks a downloaded
artifact:

```sh
git clone https://github.com/yu2001-s/MacFan.git
cd MacFan
./script/install_app.sh
```

To inspect a downloaded app before opening it:

```sh
codesign --verify --deep --strict --verbose=2 /Applications/MacFan.app
spctl -a -vv /Applications/MacFan.app
```

`codesign` verifies bundle integrity. `spctl` checks Gatekeeper policy and can
still reject development/ad-hoc signed builds.

## First fan change

The first write installs the helper:

```text
/Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
```

macOS asks for an administrator password for that install. Later fan changes
should not repeatedly ask for a password unless the helper is missing, has the
wrong permissions, or is older than the bundled helper.

The installed helper should look like this:

```sh
ls -l /Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
```

Expected permissions include `root wheel` ownership and the setuid bit:

```text
-rwsr-xr-x  1 root  wheel  ...
```

## Uninstall

Quit MacFan, then remove the app and helper:

```sh
pkill -x MacFan || true
sudo rm -rf /Applications/MacFan.app
sudo rm -f /Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
```
