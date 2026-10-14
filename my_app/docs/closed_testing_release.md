# SelfX POS closed-testing release — 4.9.0 (8042)

> Superseded by 4.9.0 (8043): The user explicitly accepted open-app order reception
> and authorized removing the foreground service. PosPresenceService, its method
> channel, Dart bridge, lifecycle calls and service notification were removed.
> FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC and POST_NOTIFICATIONS are blocked
> in the manifest. Pending-order synchronization and kitchen refresh on resume,
> in-app order alerts, Bluetooth printing, camera/QR and voice input remain.
> This release has no FCM and makes no background-delivery guarantee. The retained
> service and required declaration discussed below apply only to older releases.

8043 verification: release build succeeded; 15 order/printing/QR/voice regression
tests passed and modified Dart analysis found no issues. Both the merged manifest
and the manifest embedded in the AAB exclude PosPresenceService, every foreground
service permission, POST_NOTIFICATIONS, APK-install and broad media/storage
permissions. The AAB signature matches the existing upload key. Upload artifact:
`../.release-build/play/4.9.0+8043/app-release.aab` (80,822,008 bytes).

## Order reception and remaining integration gap

- Register/waiter new orders arrive through authenticated `/new-orders` API polling
  every eight seconds, with a baseline/cursor and existing cue deduplication.
- Kitchen and floor/bill updates use their existing API pollers.
- WebSockets exist only for the LAN customer display. No backend order WebSocket
  endpoint or client implementation was found in this workspace.
- FCM is not implemented. No firebase_messaging dependency, Firebase initialization,
  google-services.json, device-token registration route, push sender or backend
  order source is available here. The user confirmed no Firebase/backend setup to
  connect. ML Kit's Firebase component metadata does not provide FCM.
- PosPresenceService posts a persistent notification and helps retain the Android
  process. It contains no API request, order receiver, WebSocket or FCM listener.
  Keeping it preserves existing background behavior, but it does not guarantee
  delivery if Android terminates the Flutter process. Android 15's dataSync timeout
  remains applicable; the existing onTimeout implementation stops safely.

The service has **not** been removed. Reliable background new-order push cannot be
claimed or tested without a Firebase project, device-token registration and a
server-side sender. Do not remove the foreground service based only on adding an
FCM dependency. Implement and test delivery, permission denial, force-stop limits,
token refresh, store/session routing and deduplication on real devices first.

No customer notification, Accepted/Preparing transition, order acceptance or
printing status logic was changed. The existing active-app polling is retained.

## Code changes in this review

| File | Change |
| --- | --- |
| android/app/src/main/AndroidManifest.xml | Explicit optional camera.any, microphone and location hardware, avoiding device filters caused by plugins/permissions. All restricted-permission removal rules and Bluetooth permissions remain. |
| lib/providers/pos_controller.dart | Prevent overlapping new-order polls; discard a baseline or order response belonging to a previous session. Existing cursor/cue/printing logic remains. |
| lib/providers/kitchen_controller.dart | Prevent overlapping kitchen refreshes and discard responses after kitchen session teardown. |
| lib/app.dart | Refresh kitchen state and synchronize pending/failed offline orders on app resume using the existing sync engine. |
| pubspec.yaml | Version 4.9.0+8042. No dependency versions changed. |
| lib/config/pos_app_info.dart | Build metadata synchronized to 8042. |
| test/new_order_polling_test.dart | Regression coverage for overlapping polls, retry after failure and logout during a request. |
| test/pos_orders_silent_refresh_test.dart | Mock the local held-order lookup in the existing fake controller, preventing SQLite initialization from blocking this widget test. |
| docs/closed_testing_release.md | Findings, validation and manual rollout requirements. |

No UI design files, printer transports, QR scanner, voice recognizer or backend
customer status notification modules were modified.

## Permissions

The manifest retains INTERNET, ACCESS_NETWORK_STATE, CAMERA, RECORD_AUDIO,
POST_NOTIFICATIONS, BLUETOOTH_SCAN, BLUETOOTH_CONNECT, legacy BLUETOOTH and
BLUETOOTH_ADMIN (through API 30), ACCESS_FINE_LOCATION (through API 30 for legacy
Bluetooth discovery), FOREGROUND_SERVICE and FOREGROUND_SERVICE_DATA_SYNC.
The printer plugin's USB_PERMISSION declaration and AndroidX signature receiver
permission remain. Hardware access still needs the appropriate runtime/device consent.

REQUEST_INSTALL_PACKAGES, READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO,
READ_MEDIA_VISUAL_USER_SELECTED, READ_EXTERNAL_STORAGE and WRITE_EXTERNAL_STORAGE
remain explicitly blocked with tools:node="remove". Image selection retains Photo
Picker; camera capture, voice input, Bluetooth/USB printing and notification consent
remain available. See [the full permission audit](android_play_permissions.md).

## Upgrade compatibility

The inspected older 4.8.0 local APKs use `com.example.my_app` and Android Debug
signing. The universal APK has code 4041; architecture-specific APKs use 5041,
6041 and 8041. Android cannot update those APKs in place with `in.selfx.pos`.
Increasing the version code does not solve different-package/signing mismatches.
Do not promise automatic migration or uninstall a register without backing up data.

The current Play package remains `in.selfx.pos`. The new code 8042 exceeds both
the current source code 4044 and the highest inspected local APK code 8041.
Confirm Console has no higher used version before uploading; Console state is not
accessible in this workspace. The existing upload key is reused, with no key reset.
Compare the registered **upload** certificate in Console to the local upload
certificate; installed Play APKs use Google's app-signing certificate, which can
differ from the upload certificate.

Minimum Android SDK remains 24, target/compile SDK 36, matching the inspected older
universal APK. ARM64, ARMv7 and x86_64 support are retained. Camera, microphone,
location, Bluetooth and USB hardware declarations are optional to avoid unnecessary
device exclusion. Inspect Console's Device catalog to compare against the currently
published artifact; no source-only check can prove coverage of every Play user.

## Verification

- Full `flutter analyze` ran: 21 reported warning/info entries (some repeated) in
  unchanged cart_quick_pay_settings, kitchen_order_card, discount_dialog,
  pos_cart_panel and pos_navigator files. No compiler errors were reported.
- Scoped analysis of all modified Dart code/tests passed with no issues.
- All 40 tests across new-order polling, kitchen startup, silent orders refresh,
  barcode parsing, rate-limit recovery, updates, Bluetooth transport, receipts and
  voice parsing passed after fixing the incomplete test fake.
- Release build succeeded (186.2 seconds) using the existing upload key. The
  freshly generated `build/app/outputs/bundle/release/app-release.aab` was verified
  directly: application ID in.selfx.pos, version 4.9.0, code 8042; all seven blocked
  install/media/storage permissions are absent. CAMERA, RECORD_AUDIO,
  POST_NOTIFICATIONS, Bluetooth and FOREGROUND_SERVICE_DATA_SYNC remain.
- `jarsigner -verify` verified the signature; certificate SHA-256 matches the existing
  upload certificate. ARM64, ARMv7 and x86_64 libraries are present. The merged
  manifest confirms min SDK 24, target SDK 36 and optional hardware declarations.
- A version-specific copy is saved outside Flutter's output directory at
  `../.release-build/play/4.9.0+8042/app-release.aab`. Old named AAB copies were moved
  out of the output directory because Flutter can report one of those instead of
  the newly generated standard filename. Signing credentials remain local and
  excluded from Git. No Play Console upload or declaration submission was performed.

## Manual Play Console actions and release gates

1. Add the **new 8042 AAB** to a new closed-testing release. Remove/replace the old
   draft artifact; a release containing only the same retained bundles can produce
   "does not add or remove app bundles". Uploading/building locally does not modify
   Play Console release state.
2. Verify the package, highest used code, registered upload certificate and Device
   catalog coverage in the existing Play application. Package mismatch cannot be
   fixed by signing configuration. Retained older active bundles can continue to
   trigger permission declarations even when the new bundle has removed them.
3. Complete the **dataSync foreground-service declaration** with an accurate
   explanation and demonstration video. Do not describe the empty native service
   as a guaranteed background push receiver or an unlimited background connection.
   Policy approval is not guaranteed for a process-lifetime/polling service.
4. The new artifact does not require APK-install or broad photo/video permission
   declarations. Keep Data safety/privacy policy and microphone/photo-upload
   disclosures accurate, and complete any remaining App content prompts.
5. On a real Android 14/15 POS, test new external orders while visible, screen-off
   polling, app resume and pending-order upload, order acceptance, receipt/KOT
   printing, Bluetooth reconnect, camera/QR, voice, notification denial and service
   timeout. Reliable background FCM remains a prerequisite for claiming background
   push support, not a completed feature in this release.

References:
- [FCM Flutter setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [Foreground service timeouts](https://developer.android.com/develop/background-work/services/fgs/timeout)
- [Foreground service declarations](https://support.google.com/googleplay/android-developer/answer/13392821)
- [Play updates](https://support.google.com/googleplay/android-developer/answer/9859350)
