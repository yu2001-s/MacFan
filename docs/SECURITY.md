# Security Notes

MacFan reads SMC data directly from the app process and performs fan writes
through a helper installed at:

```text
/Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
```

The helper is installed as `root:wheel` with the setuid bit so SMC write calls
run with effective root privileges. The app installs or updates that helper only
after macOS asks for an administrator password.

## Helper behavior

The helper supports a narrow command set:

```text
macfanctl fans [--json]
macfanctl set-speed --id <fan-id> --rpm <rpm>
macfanctl set-mode --id <fan-id> --mode <auto|manual|0|1>
macfanctl reset
macfanctl doctor
macfanctl version
```

The app validates the installed helper by checking that it is executable, has
the setuid bit, and reports the expected helper version.

## Distribution status

Development and CI builds are not notarized. For public distribution with fewer
Gatekeeper warnings, the app should be signed with a Developer ID Application
certificate and submitted to Apple notarization.

## Reporting issues

When reporting a security issue, include:

- macOS version.
- Mac model and CPU architecture.
- MacFan version.
- The exact helper permissions from `ls -l`.
- The exact command and output, with personal information removed.
