# Android permission audit — SelfX POS 4.9.0 (4043)

> Update for 4.9.0 (8043): At the user's request, PosPresenceService, its Dart
> bridge, startup/stop calls and notification prompt were removed. FOREGROUND_SERVICE,
> FOREGROUND_SERVICE_DATA_SYNC and the service-only POST_NOTIFICATIONS permission
> are now blocked by manifest merger rules. The historical audit below describes
> earlier builds. Current order polling and in-app alerts work while POS is open;
> background delivery is not guaranteed. Replace 8042 in active tracks with 8043
> before expecting the foreground-service declaration prompt to disappear.

Application ID: `in.selfx.pos`.

## Permission sources and changes

All three application manifests (main, debug, profile), the installed Android
Flutter plugin manifests, and the release manifest merger report were inspected.
Debug/profile manifests add only INTERNET. No dependency versions were upgraded.
ML Kit/Firebase component metadata and POS printer/display integrations are retained.

| Permission / feature | Original source | Change |
| --- | --- | --- |
| REQUEST_INSTALL_PACKAGES | Main app manifest, direct APK update flow in `PosUpdateInstaller` | Removed with a manifest merger rule. Android update buttons and installer entry point now open the Google Play listing. Desktop installers are retained. |
| READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO | `open_filex` plugin | Removed with manifest merger rules. Android no longer opens downloaded APKs using this plugin. |
| READ_EXTERNAL_STORAGE | `open_filex`, also implied by CameraX WRITE_EXTERNAL_STORAGE | Removed. Selected media is copied into app cache; no shared-library traversal is used. |
| WRITE_EXTERNAL_STORAGE (through API 28) | `camera_android_camerax` | Removed. The installed CameraX plugin writes captured photos to `context.getCacheDir()`. |
| READ_MEDIA_VISUAL_USER_SELECTED | Not originally present | Blocked as a guard; system Photo Picker grants access to selected URIs. |
| FOREGROUND_SERVICE and FOREGROUND_SERVICE_DATA_SYNC | App-owned `PosPresenceService`, called by the root app | Retained to preserve the register's existing background connection/order synchronization behavior. No foreground-service permissions were introduced by installed Flutter plugins. |

`ImagePickerAndroid.useAndroidPhotoPicker` is enabled at startup. All existing
gallery pick calls use that shared platform implementation, including menu imports,
product images, and customer-display advertisements. Supported devices use Android
Photo Picker; older devices use its system document-picker fallback. Camera capture
remains available through ImagePicker and CameraX. Audio playback from bundled assets
does not require READ_MEDIA_AUDIO.

## Remaining permissions and purposes

Names below omit `android.permission.` unless otherwise stated.

| Permission | Purpose / scope |
| --- | --- |
| CAMERA | Menu/product camera capture and barcode/QR scanning; runtime consent. |
| RECORD_AUDIO | Optional speech-to-text / voice ordering; runtime consent. Product still-photo capture has audio disabled. |
| POST_NOTIFICATIONS | Register connection notification; runtime consent on Android 13+. |
| BLUETOOTH_SCAN | Discover supported Bluetooth printers/devices; `neverForLocation` flag; runtime consent on Android 12+. |
| BLUETOOTH_CONNECT | Connect to Bluetooth printers/devices; runtime consent on Android 12+. |
| ACCESS_FINE_LOCATION (maxSdkVersion 30) | Bluetooth discovery on older Android; no background-location permission. |
| BLUETOOTH, BLUETOOTH_ADMIN (maxSdkVersion 30) | Legacy Bluetooth printer discovery/connections. |
| FOREGROUND_SERVICE | Keep the existing register foreground service available. |
| FOREGROUND_SERVICE_DATA_SYNC | Existing register background network synchronization; service type `dataSync`. |
| INTERNET, ACCESS_NETWORK_STATE | POS API traffic, connectivity and synchronization. |
| USB_PERMISSION | Existing declaration supplied by `flutter_thermal_printer`; this is not an Android standard runtime permission. Actual USB device access uses UsbManager's device-specific consent. |
| in.selfx.pos.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | AndroidX-generated signature permission for protecting internal receivers. |

The merged manifest also contains library services protected by BIND_JOB_SERVICE
and a profile installer receiver protected by DUMP. These are component access
restrictions, not permissions requested by this app. Disabled CameraX and Photo
Picker metadata services are not foreground services and must remain for integrations.

## Foreground service limits

The native service is a process-lifetime aid, not a separate implementation of the
Dart synchronization engine and not a guarantee against Android process termination.
Do not describe it as an unlimited background connection in a Play declaration.
Android 15+ limits dataSync foreground services to six background hours in a 24-hour
period. `onTimeout` now stops the service safely; returning to the visible app
starts it again. No boot-start receiver, background microphone/camera/location
service, exact-alarm, full-screen intent, or battery-optimization exemption is added.

If indefinite background POS operation is required, review the task architecture
and the appropriate user-initiated background API separately; this release does
not bypass Android's dataSync limits.

## Play Console actions

1. Upload the newly built 4043 AAB, replacing the old draft bundle. Review older
   bundles retained in active testing/production tracks if Console still flags them.
2. REQUEST_INSTALL_PACKAGES and broad photo/video declarations are not needed for
   this bundle: those requested permissions are absent.
3. A **dataSync foreground-service declaration is still necessary** in App content.
   Describe the actual register background synchronization feature, what interruption
   means to the cashier, and provide a video showing the register being opened,
   its ongoing notification and the relevant background behavior. Choose the
   applicable network-transfer use case; do not claim APK installation or media-library
   access. Approval is Google's decision; declaring the permission alone does not
   guarantee policy eligibility for an always-on presence service.
4. Keep privacy policy and Data safety answers accurate for photos uploaded to the
   backend, microphone/speech recognition and POS/customer data. Removing broad
   permissions does not eliminate these disclosures.

Official references:
- [Photo/video permission policy](https://support.google.com/googleplay/android-developer/answer/14115180)
- [Foreground-service declaration requirements](https://support.google.com/googleplay/android-developer/answer/13392821)
- [Android foreground-service timeouts](https://developer.android.com/develop/background-work/services/fgs/timeout)

## Verification and device checks

Focused Android update-routing and existing version/update-model tests are in
`test/play_store_update_test.dart` and `test/pos_app_update_test.dart`. The routing
test rejects HTTP APK requests and verifies the Play listing URL; desktop update
availability is also checked. Static analysis covers every modified Dart file.

Verified on 2026-10-13:
- All 13 focused update-routing and existing update-model tests passed.
- Static analysis of the eight modified Dart/test files found no issues.
- `flutter build appbundle --release` succeeded. The first attempt encountered
  native JVM memory exhaustion; the successful retry used process-local GRADLE_OPTS
  with a 3 GB heap, two workers and in-process Kotlin compilation. Project Gradle
  memory settings were not changed.
- The release merged manifest and the manifest embedded in the signed AAB contain
  version code 4043, version 4.9.0 and application ID in.selfx.pos. All seven removed
  install/media/storage permissions listed above are absent from the AAB manifest.
- `jarsigner -verify` verified the AAB signature. Its certificate SHA-256 matches
  the existing upload certificate and is not Android Debug:
  `4C:4A:51:31:A9:FB:1C:39:4F:43:B2:29:4F:54:6A:D4:C9:89:F9:C6:69:79:E0:5D:4C:C2:F0:C0:CF:03:2E:E3`.

Output: `build/app/outputs/bundle/release/app-release.aab` (80,817,095 bytes).
The existing upload keystore and key.properties remain ignored by Git.

Before production rollout, smoke-test on an Android POS device: gallery selection,
camera capture and barcode scan, Bluetooth/USB printing, customer display images,
voice entry, notification consent and register behavior while backgrounded. These
hardware/system UI checks cannot be established by host-side unit tests alone.

## Follow-up bundle 4044

On 2026-10-13, the app/plugin manifests were checked again for
REQUEST_INSTALL_PACKAGES. The only source occurrence is the app's
`tools:node="remove"` merger safeguard; no installed Flutter plugin requests it.
The removal marker is not a requested permission in the built app.

A new `4.9.0+4044` release was built and verified with the existing upload key.
Both the release merged manifest and the AAB's embedded manifest exclude
REQUEST_INSTALL_PACKAGES and the removed broad media/storage permissions. The
AAB signature matches the same upload certificate recorded above. No dependency,
foreground-service or application-functionality changes were made for this rebuild.

Upload `build/app/outputs/bundle/release/app-release-4.9.0-4044.aab`
(80,817,042 bytes). The normal `app-release.aab` output contains the same bundle.
Replace older draft bundles and inspect retained bundles in active Play tracks if
Console continues to flag an APK-install permission. The dataSync foreground-service
declaration remains necessary.
