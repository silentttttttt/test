# WebBrowse 3.0 Audit

## Scope
Full static review of the 2.9 project with additional review of WebKit content blocking, video playback/history flow, privacy storage, navigation security, downloads, app lock, and Xcode project structure.

## Bugs/issues found and fixed
1. **Content blocker could fail closed incorrectly.** The previous installer removed the active rule lists before knowing whether the replacement compiled. It now installs the replacement only after successful compilation, so a bad rule cannot silently disable the existing blocker.
2. **Content-blocking rules contained a questionable/unsupported `raw` resource type.** Those entries were replaced with explicit supported request categories used by the tracker rules, reducing the chance of WebKit rejecting the whole compiled list.
3. **Recently Watched was recorded before playback was actually attempted.** Native-player history is now recorded when the native player is presented, while HTML5 in-page history is recorded only after the page reports that playback started.
4. **Embedded-video history could lose the original source-page URL.** The source page URL and original detected media URL are now carried through embedded-player resolution into the native player.
5. **Corrupt Recently Watched data could be treated as a hard failure.** The history reader now safely discards malformed history data in memory and can replace it on the next successful write.

## Privacy/security review
- Content blocking still uses WebKit's compiled `WKContentRuleList` mechanism.
- Ad and tracker switches remain independent.
- Rule compilation no longer fails open by clearing the currently installed list first.
- Private browsing continues to use `WKWebsiteDataStore.nonPersistentDataStore` behavior.
- Recently Watched is local-only and protected with complete file protection.
- Native video playback only receives cookies whose domain/path/security attributes match the requested media host.
- Suspicious URL protection remains a heuristic layer, not a malware reputation database.
- Packet Tunnel remains fail-closed until a real relay/VPN server is configured.

## Video/history review
- Stable video IDs are used for HTML5 candidates.
- Source page URL is captured when candidates are reported, so later navigation does not change the recorded origin.
- Direct MP4/MOV/M4V/HLS playback continues to use AVPlayer.
- Embedded players are resolved only when they expose a native-playable URL; DRM/MSE/blob/protected internals are not bypassed.
- Recently Watched stores title, source website host, exact source-page URL, detected media URL when available, and watch time.

## Validation performed
- Swift source syntax parsed with `swiftc -parse` for every Swift file.
- All Info.plist and entitlement property lists parsed successfully.
- Content-blocker JSON parsed successfully.
- Xcode project references and build-file entries checked.
- App icon dimensions checked.
- ZIP integrity checked with `unzip -t`.

## Platform limitation
A real Xcode/iPhone build was not performed because the environment does not contain Apple's Xcode/iOS SDK. Static validation cannot replace a physical-device build/test.
