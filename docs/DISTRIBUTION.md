# Distribution

The easiest public distribution path is:

1. Publish `MacFan.app` on GitHub Releases.
2. Publish `raycast-macfan` to the Raycast Store.
3. Tell users to install MacFan first, open it once, and make one fan change so
   macOS installs the privileged helper.
4. Then users install the Raycast extension and control fans from Raycast.

The Raycast extension intentionally does not bundle `macfanctl`. It calls the
installed helper at:

```text
/Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
```

That keeps SMC writes behind the same macOS administrator prompt and helper
validation path as the app.

## Mac App Release

Build the public zip:

```sh
./script/package_release.sh 0.2.1
```

Upload both files from `artifacts/` to a GitHub Release:

```text
MacFan-0.2.1-macos.zip
MacFan-0.2.1-macos.zip.sha256
```

For a smooth public download, use a Developer ID Application certificate,
hardened runtime, and Apple notarization. Ad-hoc or Apple Development signed
builds are fine for testing, but users will see more Gatekeeper friction.

Recommended release notes:

```markdown
## Install

1. Download `MacFan-0.2.1-macos.zip`.
2. Unzip it and move `MacFan.app` to `/Applications`.
3. Open MacFan.
4. Make one fan change so macOS can install the privileged helper.
5. Optional: install the Raycast extension to control fans from Raycast.
```

## Raycast Store Release

Before publishing:

1. Update `author` in `raycast-macfan/package.json` to your real Raycast handle.
2. Keep `package-lock.json` committed.
3. Keep `raycast-macfan/CHANGELOG.md` updated.
4. Confirm the latest MacFan GitHub Release exists.

Validate locally:

```sh
cd raycast-macfan
npm install
npm run build
npm run lint
```

Publish:

```sh
npx ray login
npm run publish
```

Raycast's publish command opens a pull request against `raycast/extensions`.
After Raycast review and merge, the extension appears in the public Raycast
Store.

## Homebrew Later

Once the app has a stable notarized release, add a Homebrew Cask. If the project
is not accepted into `homebrew/cask` yet, start with a personal tap so users can
install with:

```sh
brew tap yu2001-s/macfan
brew install --cask macfan
```

Homebrew casks need a versioned download URL, SHA-256 checksum, app name,
description, homepage, and install target.
