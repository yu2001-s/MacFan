# Distribution

The easiest public distribution path is:

1. Publish `MacFan.app` on GitHub Releases.
2. Tell users to install MacFan first, open it once, and make one fan change so
   macOS installs the privileged helper.

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
```

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
