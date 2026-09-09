# WebBrowse 4.1 — Video/Build Fix Audit

## Fixed
- Added missing PBXFileReference entries for `VideoCandidate.swift` and `VideoDetector.swift`.
- Kept both files in the WebBrowse target Sources build phase.
- Removed the Packet Tunnel target from this LiveContainer edition.
- Bumped app version to 4.1 (build 41).

## Video detection improvements
- HTML5 `<video>` detection with stable element IDs.
- `<source src>` and `data-src` support.
- Shadow DOM traversal.
- Direct MP4/MOV/M4V/WebM/HLS (`.m3u8`) URL discovery.
- Open Graph/Twitter video metadata discovery.
- Common embedded-player iframe detection.
- Relative URLs are resolved against the current page.
- Duplicate candidates are filtered before reaching the UI.
- Detection is capped to the configured limit (1–50).
- MutationObserver rescans dynamically inserted players.

## Static validation performed
- All 21 Swift source files in `WebBrowse/` are represented in `project.pbxproj`.
- `VideoCandidate.swift` and `VideoDetector.swift` have both file references and Sources build entries.
- No `NetworkExtension`, Packet Tunnel, or `DNSManager.swift` references remain in the LiveContainer project.
- Swift source brace-balance check passed.

## Important limitation
This is a source/project audit performed outside macOS/Xcode. The final compile still needs to be run by the GitHub macOS runner.
