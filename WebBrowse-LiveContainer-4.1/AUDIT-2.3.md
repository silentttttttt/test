# WebBrowse Ultimate 2.3 — Performance, Video Downloads & Privacy Audit

## Performance
- Reuses a shared WKProcessPool to reduce repeated WebKit process setup.
- Video detection now debounces DOM changes and only sends results when its signature changes.
- Detection is capped at 50 candidates instead of repeatedly scanning hundreds of elements.
- Low-memory mode is available and automatically applies a conservative setting on devices reporting under 4 GB physical memory.
- No manual `viewDidLoad()` calls are used during rebuilds.

## Video system
- Top-right video button lists detected HTML5 videos and supported embedded players.
- Each video can be watched.
- Direct MP4/MOV/M4V links can be downloaded using a background URLSession.
- Completed downloads are stored in the app's Documents/Downloads directory and can be shared/saved to Files.
- HLS (`.m3u8`), blob URLs, MSE and DRM-protected media are not falsely treated as ordinary downloadable files.
- Video detection is limited to the main document; cross-origin iframe DOM is not accessed.

## Privacy/security
- Existing content blocking, tracker blocking, private WebKit data store, HTTPS upgrade, encrypted DNS, redirect protection and no-analytics design remain enabled.
- Unknown URL schemes remain blocked instead of being launched blindly.
- Downloading only accepts HTTP(S) direct media URLs.
- Private mode continues to use WKWebsiteDataStore.nonPersistent().

## Signing
- Both the app and Packet Tunnel targets retain CODE_SIGN_STYLE = Automatic.
- DEVELOPMENT_TEAM is intentionally blank so the user can choose their own Team in Xcode.
- Packet Tunnel is embedded through the app's Embed App Extensions build phase.

## Remaining limitations
- A real Packet Tunnel relay/VPN server is still required to hide the public IP.
- Background download sessions support HTTP/HTTPS direct files; HLS offline downloads would require a dedicated AVAssetDownloadURLSession implementation and server/media compatibility testing.
- A real Xcode build/sign/device test still requires macOS/Xcode and the user's Apple account.
