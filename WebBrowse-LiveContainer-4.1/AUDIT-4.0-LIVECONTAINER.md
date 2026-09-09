# WebBrowse 4.0 LiveContainer Audit

- Removed Packet Tunnel app-extension target, dependency, embedded extension, source group, product, and extension entitlements.
- Removed NetworkExtension-based encrypted DNS implementation and UI from this LiveContainer edition.
- Removed NetworkExtension import/status checks from Privacy Dashboard.
- App entitlements are now empty; Xcode can manage signing without the Network Extension capability.
- Updated app version to 4.0 (build 40).
- Verified App Lock password UI uses the same 8–256 character requirement as AppLockManager.
- Added LiveContainer-specific README instructions.

Expected result: a single iOS application target named WebBrowse, with no embedded app extension.
