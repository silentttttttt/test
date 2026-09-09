# WebBrowse 3.6 — 40-Point Bug & Hardening Audit

This pass re-audited the complete 3.5 project and applied 40 fixes/hardening items. Items 1–20 are retained/revalidated from the previous major audit; items 21–40 are additional fixes in 3.6.

## 1–20 retained/revalidated
1. Content-blocker collateral removal
2. Content-blocker disable cleanup
3. Invalid blocker resource type removed
4. Compiled blocker cache cleanup
5. Stale video-page association protection
6. Recently Watched source URL normalization
7. Recently Watched duplicate matching
8. History file/data protection
9. Native-player browser-cookie leakage removed
10. Native-player error race protection
11. Embedded-video resolver URL security
12. Resolver timeout increased for slow sites
13. Automatic redirect-chain protection
14. Navigation-response URL security checks
15. Download HTTP response validation
16. 20 GB download safety limit
17. Download progress clamping
18. Media-response validation
19. Background-download callback locking
20. App-lock password hardening and backoff

## 21–40 new in 3.6
21. **Redirect-window reset bug fixed** — provisional navigation no longer resets the redirect counter on every redirect, which could otherwise defeat loop protection.
22. **Content-process reload loop limited** — repeated WebKit content-process crashes cannot cause immediate endless reloads.
23. **URL length cap added** — unusually long URLs are rejected before WebKit processing.
24. **Local/private-host warning added** — localhost, link-local, RFC1918, and similar private addresses receive a warning under suspicious-URL protection.
25. **Programmatic navigation now uses the same URL security gate** — home/history/search loads no longer bypass the heuristic layer.
26. **Popup navigation security tightened** — popup-created destinations are checked before being loaded.
27. **JavaScript dialog flood protection added** — abusive pages cannot continuously stack native alert/confirm/prompt dialogs.
28. **Dialog counters reset after successful navigation** — legitimate sites regain normal dialog behavior on a new page.
29. **Video resolver redirect cap added** — hidden resolver web views stop after an excessive redirect chain.
30. **Video resolver validates each navigation action** — unsupported schemes and blocked destinations are rejected before loading.
31. **Video resolver URL length cap added** — malformed oversized resolver URLs are rejected.
32. **Native video URL validation added** — WebBrowse's AVPlayer is only given HTTP(S) media URLs.
33. **Native player pauses when dismissed/backgrounded** — reduces unnecessary playback, CPU, and network use.
34. **Native-player error alert deduplication** — a single failing AVPlayer item cannot repeatedly present identical alerts.
35. **Video iframe duplicate suppression** — repeated references to the same embedded player no longer create duplicate menu entries.
36. **Video detector watches `<source type>` changes** — dynamically changed media declarations trigger re-detection.
37. **Recently Watched file-size sanity check** — an unexpectedly large/corrupt history file is ignored instead of consuming excessive memory.
38. **Recently Watched title length capped** — hostile or enormous page titles cannot bloat the history database.
39. **History-save retry bounded** — failed writes retry a small number of times instead of retrying forever.
40. **DNS/download input hardening** — DoH endpoints have bounded HTTPS validation; download URLs reject credentials and oversized addresses before scheduling network work.

## Additional review areas
- WKWebView lifecycle and content-process recovery
- WKContentRuleList compilation and installation
- ad/tracker blocking
- popup and redirect handling
- suspicious URL heuristics
- private browsing and website-data separation
- Recently Watched privacy and storage
- native AVPlayer playback
- video detection/resolution
- background downloads
- Photos saving
- App Lock / Keychain
- custom app icons
- low-memory behavior
- encrypted DNS
- Network Extension project configuration
- Automatic Signing project configuration

## Validation
- Swift syntax parsing: passed for every WebBrowse and Packet Tunnel Swift file.
- Property-list validation: passed.
- Content-blocker JSON validation: passed.
- Xcode project assertions: passed.
- ZIP integrity: passed.

## Important limitation
No physical iPhone/Xcode build was performed because Apple's Xcode/iOS SDK is not available in this environment. A real-device build and runtime test remains necessary before release.
