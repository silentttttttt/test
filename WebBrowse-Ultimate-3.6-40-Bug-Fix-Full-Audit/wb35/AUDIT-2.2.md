# WebBrowse 2.2 Audit & Fix Report

## Bugs/risks found and fixed

1. **Packet Tunnel extension was not embedded in the main app target.**
   - Added an `Embed App Extensions` copy-files phase containing `WebBrowsePacketTunnel.appex`.
   - Kept the target dependency so Xcode builds the extension before the app.

2. **Embedded-player rows could fail silently.**
   - Selecting an embedded YouTube/Vimeo/etc. candidate previously passed `elementIndex = -1` into the HTML5-video playback path.
   - Embedded candidates now navigate to the detected player URL instead.

3. **Video detection ran inside every iframe.**
   - This could produce duplicate results and, more importantly, an iframe-local `<video>` index could be used against the top-level page and play the wrong element.
   - Detection is now limited to the top-level document. Common embedded players are still identified from iframe URLs.

4. **Video result duplication / unbounded list.**
   - Results are deduplicated and capped at 100 entries.
   - Previous-page results are replaced rather than appended.

5. **Redirect protection was too aggressive.**
   - A single cross-site redirect could break legitimate SSO, OAuth, payment, and CDN flows.
   - The protection now permits a small number of cross-host redirects and blocks only rapid excessive redirect chains.

6. **HTTPS upgrade could lose URL components.**
   - Replaced manual string rebuilding with `URLComponents`, preserving ports, fragments, queries, and other components when upgrading HTTP to HTTPS.

7. **Custom URL schemes were not explicitly controlled.**
   - Navigation policy now only permits `http`, `https`, and `about` schemes. Other schemes are cancelled instead of being silently handed to another app.

8. **Missing JavaScript confirm/prompt handling.**
   - Added native confirmation and text-input dialogs in addition to JavaScript alerts.

9. **WebKit content-process termination could leave a blank page.**
   - Added `webViewWebContentProcessDidTerminate` to reload the current page after WebKit terminates its content process.

10. **Encrypted DNS toggle could remain visually enabled after a failed configuration.**
    - The setting now rolls back if the DNS profile fails to enable/disable.
    - Browser rebuild occurs only after a successful DNS state change.

11. **Direct WebM playback was incorrectly sent to AVPlayer.**
    - WebM is left to WebKit instead of assuming native AVPlayer support.

12. **Search/home URL handling contained avoidable force-unwrapping.**
    - Invalid generated URLs now fail safely instead of crashing.

## Improvements added

- Loading progress bar.
- Reload button changes behavior to stop while a page is loading.
- Share-page action.
- Automatic recovery after WebKit content-process termination.
- Safer native-video type selection.
- Video detector debounce and scan limits.
- Privacy dashboard now checks actual Network Extension tunnel connection state instead of always displaying a static IP-protection message.

## Verification performed in this environment

- All Swift source files were successfully syntax-parsed with `swiftc -parse`.
- Both Info.plist files successfully parsed as property lists.
- The Xcode project contains both targets and now contains an explicit app-extension embedding phase.
- No `try!` or force-unwrapped URL creation remains in the browser source paths reviewed.

## Not claimed

A full iOS device build/sign/install test cannot be performed without Apple's Xcode/iOS SDK and signing environment. The project is structured for Xcode Automatic Signing, but final compilation and entitlement approval must still be performed by Xcode with the user's Apple Developer Team.

The Packet Tunnel remains deliberately non-functional until a real VPN/relay protocol and server are configured. This prevents a false claim that the browser is hiding the user's public IP.
