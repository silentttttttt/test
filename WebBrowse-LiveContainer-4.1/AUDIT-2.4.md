# WebBrowse 2.4 audit

## Performance
- Video detection no longer rescans the entire DOM for every arbitrary mutation. MutationObserver work is triggered only when added nodes contain a video, source, or iframe.
- Detection is debounced and capped at 30 candidates on lower-memory devices and 50 otherwise.
- Low-memory mode is automatically effective on devices with approximately 4 GB RAM or less, while the manual setting can still force it on.
- The browser keeps the shared WebKit process pool and normal WebKit caching behavior instead of adding custom caches that could increase memory use.
- The video button uses a compact iOS configuration and only appears when candidates exist.

## Video features
- Video candidates can be watched, downloaded, saved in WebBrowse, shared, or saved to Photos for MP4/MOV/M4V.
- Direct downloads are limited to HTTP(S) URLs and common media extensions.
- HTML responses masquerading as downloads are rejected.
- DRM/MSE/blob media is not extracted or bypassed; the page's own player remains responsible for protected playback.

## Privacy
- Private browsing continues to use a non-persistent WKWebsiteDataStore.
- Encrypted DNS remains opt-in and rolls back the UI toggle when configuration fails.
- The privacy dashboard now checks only WebBrowse's Packet Tunnel provider instead of treating an unrelated VPN on the phone as WebBrowse IP protection.
- No analytics, telemetry, or third-party tracking SDKs were added.
- Download requests use a dedicated background URLSession rather than the browser's persistent WebKit cookie store.

## Signing
- Both the main app and Packet Tunnel targets retain `CODE_SIGN_STYLE = Automatic`.
- No certificate, provisioning profile, or Team ID is embedded.
- Packet Tunnel remains explicitly embedded in the host application.

## Static checks
- All Swift files pass `swiftc -parse` in the available environment.
- App and extension Info.plist files parse successfully.
- Project references include all source files, including PhotoSaver.swift.

## Known platform limitation
A real public-IP-hiding VPN still requires a real tunnel protocol and relay/VPN server. The Packet Tunnel extension deliberately fails closed rather than claiming IP protection without a server.
