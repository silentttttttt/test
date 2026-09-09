# WebBrowse Ultimate 4.0 — LiveContainer Edition

This edition is prepared specifically for LiveContainer. It removes the Network Extension / Packet Tunnel / system encrypted-DNS components so the guest app has no extension target or Network Extension entitlement. The browser, WebKit privacy protections, content blocking, video detection/player, downloads, app lock, private browsing, customization, and local history remain included.

## Build an IPA on macOS
1. Open `WebBrowse.xcodeproj` in Xcode.
2. Select the **WebBrowse** target.
3. In **Signing & Capabilities**, choose your Apple Account/Personal Team and leave **Automatically manage signing** enabled.
4. Choose **Any iOS Device (arm64)** (or a connected iPhone).
5. Use **Product → Archive**.
6. In Organizer, select the archive → **Distribute App** → choose a development/export option appropriate for sideloading → export the IPA.

## LiveContainer
LiveContainer can import IPA files with its `+` button. For JIT-less operation, first import the signing certificate from AltStore/SideStore in LiveContainer settings and run **JIT-Less Mode Diagnose → Test JIT-Less Mode**. Then use **+** to import the exported `WebBrowse.ipa`.

## Intentional LiveContainer tradeoff
Encrypted DNS and the Packet Tunnel/VPN extension are not included in this build. This avoids Network Extension/extension-signing requirements that can interfere with guest-app signing. WebBrowse does not claim to hide your public IP.

## Notes
- This source package is not itself a signed IPA. Signing/export happens in Xcode on macOS.
- Use the official LiveContainer build; third-party closed-source builds can access guest-app data.
