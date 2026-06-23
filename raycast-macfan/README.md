# MacFan Raycast Extension

This local Raycast extension controls MacFan through the installed privileged
`macfanctl` helper.

## Setup

1. Install MacFan and make one fan change from the MacFan app so macOS prompts
   to install the privileged helper.
2. Verify the helper exists:

   ```sh
   ls -l /Library/PrivilegedHelperTools/com.shaoyuhuang.MacFan.macfanctl
   ```

3. Start the Raycast extension:

   ```sh
   cd raycast-macfan
   npm install
   npm run dev
   ```

4. In Raycast, use `Control Fans`, `All Fans Auto`, or `All Fans Max`.

If you install the helper somewhere else, open Raycast Preferences, find the
MacFan extension, and update `macfanctl Helper Path`.

`npm run build` validates the extension locally. `npm run lint` also verifies
that the `author` field in `package.json` is a real Raycast account, so update
that value to your Raycast handle before publishing or relying on lint.

Manual fan control can affect temperature, noise, and fan wear. Use conservative
RPM values and return to Auto when you no longer need manual control.
