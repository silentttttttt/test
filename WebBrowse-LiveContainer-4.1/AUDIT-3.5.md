# WebBrowse 3.5 — 20-Bug Full Audit

## 20 fixes / improvements
1. **Content-blocker collateral removal** — stopped WebBrowse from removing unrelated WKContentRuleLists owned by the host app.
2. **Content-blocker disable cleanup** — disabling protection now removes only WebBrowse-owned rule lists.
3. **Invalid blocker resource type** — removed the unsupported `xhr` resource type and used the WebKit-supported `fetch` type, preventing rule compilation failures.
4. **Blocker cache cleanup** — stale WebBrowse rule-list versions are removed without touching unrelated lists.
5. **Stale video-page association** — delayed detector results from an older page are rejected when their source URL no longer matches the current page.
6. **History source URL normalization** — Recently Watched now stores the validated canonical absolute source URL rather than the raw detector string.
7. **History duplicate matching** — duplicate detection now uses the normalized media URL, preventing duplicate entries caused by equivalent URL representations.
8. **History storage protection** — the Recently Watched directory receives iOS Data Protection in addition to the protected file.
9. **Native-player cookie leakage** — removed automatic browser-cookie injection into AVPlayer headers because an AVURLAsset request can follow redirects and could expose a Cookie header to a redirected host.
10. **Native-player error race** — playback errors are no longer presented after the player view has disappeared.
11. **Embedded-video resolver security** — resolver URLs are passed through NavigationSecurity before a hidden WKWebView is created.
12. **Embedded-video resolver timeout** — increased the resolver timeout from 8 to 15 seconds to reduce false failures on slower sites.
13. **Redirect-loop protection** — automatic redirect chains are now counted even when the host stays the same, preventing same-host redirect loops from escaping the protection.
14. **Navigation-response security** — final navigation responses are checked by the same URL-security layer, catching malformed/blocked destinations that appear after the initial navigation action.
15. **Download HTTP-response validation** — downloads now require a valid HTTP response and a 2xx status before being accepted.
16. **Download size enforcement** — the 20 GB limit is checked against both expected response size and the actual received file size.
17. **Download progress bounds** — reported progress is clamped to 0...1 so UI consumers cannot receive invalid progress values.
18. **Media-response validation** — downloads that are neither media MIME types nor known media-extension requests are rejected instead of being saved as arbitrary files.
19. **Background-download callback race** — background URLSession completion-handler state is protected by the same lock used for task completion state.
20. **App-lock password hardening** — password comparison is constant-time and failed password attempts receive increasing in-memory backoff; the minimum new password length is now 8 characters.

## Additional audit pass
- Rechecked video detection, native playback, Recently Watched, downloads, Photos saving, app locking, private browsing, encrypted DNS, popup/redirect protection, suspicious URL protection, custom icons, low-memory behavior, project signing, entitlements, and Network Extension embedding.
- No analytics or third-party tracking SDKs were added.
- The native player intentionally does not bypass DRM, protected media, or browser security controls.

## Validation
- Swift syntax parsing: passed for all WebBrowse and Packet Tunnel Swift files.
- Property-list parsing: passed.
- Content-blocker JSON parsing: passed.
- Xcode project assertions: passed.
- ZIP integrity: passed.

## Limitation
No physical iPhone/Xcode build was performed because Apple's Xcode/iOS SDK is unavailable in this environment. The final build/device test must still be performed in Xcode on macOS.
