# WebBrowse Ultimate 3.5

WebBrowse is a WKWebView-based iOS browser project with privacy filtering, native video playback, downloads, app lock, customizable icons, and automatic signing configuration.

## 2.7 highlights
- Expanded ad/tracker blocking.
- Conservative suspicious-URL protection.
- Stable video detection IDs instead of fragile DOM indexes.
- Shadow-DOM video detection where page access permits it.
- Better embedded-video resolution, including media MIME declarations and common social media metadata.
- Native AVPlayer improvements for buffering and error observation.
- Download content sniffing to reject mislabeled HTML pages.
- Automatic media filename extensions from response MIME types.
- 1024×1024 app-icon metadata corrected.

## Custom app icon
1. Open `WebBrowse.xcodeproj` on a Mac in Xcode.
2. Open `WebBrowse/Assets.xcassets/AppIconCustom.appiconset`.
3. Replace `AppIconCustom.png` with your own **1024×1024 PNG**.
4. Keep the filename `AppIconCustom.png` (or update `Contents.json` if you rename it).
5. Build/install the app.
6. Open WebBrowse Settings → Customize WebBrowse → Custom.

The Home Screen icon itself cannot be an animated GIF. iOS app icons are static; an animated GIF can be used inside the app instead.

## Protection notes
The content blocker uses WebKit's compiled content-rule system. It blocks a curated set of common ad/tracker/telemetry hosts and some tracking-pixel patterns. The suspicious-URL layer is intentionally conservative and is **not** a replacement for an antivirus or a continuously updated Safe Browsing reputation service.

## Video notes
WebBrowse tries to use its native player first. Direct MP4/MOV/M4V/HLS URLs can be handed to AVPlayer when accessible. HTML5 videos without a normal file extension can still be offered for download when their server response identifies them as media. DRM, MSE/blob-only media, and protected player internals are not extracted or bypassed.

## Automatic signing
1. Open `WebBrowse.xcodeproj` in Xcode on macOS.
2. Select the `WebBrowse` target → Signing & Capabilities.
3. Select your Apple Developer Team.
4. Leave Automatically manage signing enabled.
5. Select `WebBrowsePacketTunnel` and choose the same team.
6. If Network Extension capability approval is required for your Apple Developer account, configure/approve it.
7. Connect your iPhone and Build & Run.

The project cannot be compiled/sign-installed here because Xcode and Apple's iOS SDK are not available in this environment.


## WebBrowse 2.9 — Recently Watched Videos
- Selecting **Watch in WebBrowse Player** from the detected-video menu records the video in Recently Watched.
- Each record stores the exact source webpage URL, source host, video title, media URL when available, and watch time.
- History is capped at 100 entries, deduplicated when the same source page/media is watched again, and stored in an app-support file using iOS complete file protection.
- Open **Recently Watched** from the detected-video menu to view entries, open the exact source webpage, share its exact URL, or clear history.
- Protected/private browsing can be used without sending history to any server; this history is local to WebBrowse.


## 3.0 audit notes
- Content-blocker replacement now preserves the previous compiled blocker if a new rule list fails to compile.
- Recently Watched is recorded after playback is successfully handed to the native player or after an HTML5 video reports a successful play request.
- The original source-page URL is carried through embedded-video resolution and stored locally.


## WebBrowse 3.3

This release reuses compiled content-blocking rules, cleans stale WebBrowse rule-list cache entries, and adds additional malformed/raw-IP URL safety checks.


## WebBrowse 3.5
- Video detections now carry the exact main-frame source page URL from the web document itself, preventing delayed detector messages from accidentally being attributed to a newer page.
- Detected-video lists are cleared at the beginning of navigation so videos from the previous page cannot remain selectable.
- The security layer only permits the standard `about:blank` page instead of arbitrary `about:` URLs.
- Downloads have a 20 GB safety ceiling to prevent accidental extreme disk consumption.
