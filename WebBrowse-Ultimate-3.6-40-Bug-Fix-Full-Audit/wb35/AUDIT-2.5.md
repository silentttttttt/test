# WebBrowse 2.5 audit

## Changes
- Added a native-first video workflow: detected direct MP4/MOV/M4V/HLS media opens in AVPlayer.
- Added embedded-player resolution: WebBrowse opens an embedded player URL in an isolated resolver and looks for a native-playable `<video>/<source>` URL. If none is exposed, it falls back to the site player rather than bypassing DRM/MSE/protected playback.
- Native playback reuses matching WebKit cookies for authenticated media requests when available.
- Fixed the native player title initialization bug from 2.4.
- Added App Lock using Face ID and a custom WebBrowse password.
- App passwords are salted and iterated before being stored as a one-way hash in the device Keychain.
- Added lock-on-background behavior and a privacy shield to hide page content in the app switcher snapshot.
- Added alternate app icons: Default, Midnight, Ocean, Sunset, Forest.
- Added customization settings for icon selection.
- Added explicit iOS Data Protection attributes to downloaded files; Saved Videos use complete protection.
- Added `NSFaceIDUsageDescription`.
- Kept Automatic Signing enabled and preserved the Packet Tunnel target.

## Static verification
- `swiftc -parse` passed for every Swift source file.
- Both Info.plist files parse successfully.
- Xcode project contains automatic signing, embedded Packet Tunnel, app-lock sources, native video resolver, and asset catalog build settings.
- All app icon asset catalogs contain valid `Contents.json` and 1024x1024 PNG assets.
- ZIP integrity test passed.

## Not performed
- No actual iOS device build/install was performed because this environment does not contain macOS/Xcode/iOS SDK tooling.
- Network Extension Packet Tunnel remains a fail-closed integration point until a real VPN/relay protocol and server are configured.
