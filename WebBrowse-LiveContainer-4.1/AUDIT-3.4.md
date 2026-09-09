# WebBrowse 3.4 Audit

## Changes
- Added exact source-page URL to detector payloads so recently watched entries and detected-video actions remain tied to the page that actually produced the detection.
- Rechecked navigation lifecycle: detected videos are cleared when a new navigation starts, preventing stale candidates from surviving across pages.
- Tightened the `about:` navigation policy to allow only `about:blank`.
- Added a 20 GB maximum expected-response size for background downloads as a disk-consumption safety guard.
- Rechecked content-blocker compilation/reuse, URL heuristics, native playback, private-mode history exclusion, protected history storage, download response validation, app lock, DNS, custom icons, and automatic signing.

## Validation
- Swift syntax parsing: passed.
- Property-list validation: passed.
- Xcode project/reference assertions: passed.
- Content-blocker JSON validation: passed.
- ZIP integrity: passed.

## Limitation
No physical iPhone/Xcode build is performed in this environment because Apple's Xcode/iOS SDK is unavailable here.
