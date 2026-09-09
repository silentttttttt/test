# WebBrowse 2.7 Audit

## Static checks
- All Swift source files pass `swiftc -parse`.
- `Info.plist` parses successfully.
- Embedded `WKContentRuleList` JSON parses successfully.
- Project references for the new `NavigationSecurity.swift` source are present in the Xcode project.
- App icon PNGs are all 1024×1024.
- ZIP integrity checked with `unzip -t`.

## Bugs/issues found and fixed
1. **Video list used array indexes as video identity.** Dynamic pages can insert/remove videos, making an old index point to the wrong video. Replaced indexes with stable `data-webbrowse-video-id` values and added shadow-DOM traversal.
2. **Cross-host redirect protection could affect subframes.** Redirect counting is now limited to main-frame navigations.
3. **Video resolver rejected media URLs without file extensions.** It now accepts declared HTML media MIME types and common Open Graph/Twitter media metadata.
4. **Native player used manual KVO cleanup.** Replaced it with `NSKeyValueObservation` and added modest buffering/stall configuration.
5. **Downloads could accept mislabeled HTML pages.** Added MIME rejection for HTML/text/JSON/XML and a small first-512-byte HTML sniff without loading the entire downloaded file into memory. MIME-only downloads can receive a safe extension.
6. **Xcode icon metadata was incomplete.** App icon sets now explicitly identify the 1024×1024 universal icon size.
7. **No local suspicious-URL protection existed.** Added a conservative navigation guard that blocks embedded credentials and unsupported schemes and warns on punycode domains. It is deliberately described as a heuristic layer, not a full malware reputation service.
8. **Settings lacked a user control for the suspicious-URL layer.** Added “Suspicious URL protection,” enabled by default.
9. **Removed a duplicate toolbar removal call during settings rebuild.**

## Privacy/security improvements
- Expanded common ad/tracker blocking domains and telemetry providers.
- Added image-only tracking pixel/beacon blocking patterns.
- Kept private WebKit storage, HTTPS upgrade, encrypted DNS, popup protection, redirect protection, app lock, privacy shield, and data protection for saved videos.
- The browser does not claim that encrypted DNS hides the public IP.
- The Packet Tunnel extension still fails closed until a real relay/VPN protocol and server are configured.

## Video improvements
- Stable video identities survive DOM insertion/reordering better.
- Shadow-root HTML5 videos are scanned when accessible to the page.
- Embedded player resolution can use media MIME declarations and social-media media metadata.
- Native AVPlayer remains the preferred playback path when a direct playable URL is exposed.
- DRM, MSE/blob-only streams, and protected player internals are not extracted or bypassed.
- Direct video downloads remain background URLSession downloads.

## Known platform limitations
- WKContentRuleList is a content-filtering layer, not a complete antivirus engine.
- No local or remote reputation feed is bundled, so the suspicious-URL layer cannot guarantee detection of newly created malicious sites.
- Background URLSession downloads follow redirects at the system level; the app does not attempt to bypass Apple's background-session behavior.
- HLS can be played by AVPlayer when accessible, but ordinary video-file saving is limited to exposed direct media URLs. Offline HLS asset downloading would require a separate AVAssetDownloadURLSession workflow.
- A real device/Xcode build was not performed in this environment because Apple's iOS SDK/Xcode are unavailable here.
