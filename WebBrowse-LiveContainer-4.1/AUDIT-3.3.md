# WebBrowse 3.3 Audit

## Changes
- Reused compiled WebKit content-rule lists when settings are unchanged.
- Cleaned up stale WebBrowse-owned compiled content-rule lists to avoid persistent cache growth.
- Preserved the fail-closed behavior when a replacement content-rule list cannot compile.
- Added URL sanity checks for control characters/newlines.
- Added a warning for raw IP-address navigation instead of silently treating it as an ordinary domain.
- Rechecked native video playback/history flow, private-mode history exclusion, downloads, app lock, custom icons, DNS settings, redirect protection, and automatic signing configuration.

## Validation
- Swift syntax parsing: passed.
- Property-list validation: passed.
- Xcode project/reference assertions: passed.
- Content-blocker JSON validation: passed.
- ZIP integrity: passed.

## Limitation
No physical iPhone/Xcode build is performed in this environment because Apple's Xcode/iOS SDK is unavailable here.
