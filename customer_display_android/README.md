# SELFX Customer Display

This companion app lives alongside `../my_app` in the SelfX POS repository.
It is a separate Android application (`com.selfx.pos.customer_display_android`)
and supports the POS's secure protocol-v2 pairing screen. It does not replace
the POS app or its `in.selfx.pos` package.

Android-only companion display for the SELFX Windows POS.

## Pairing

1. Connect the Windows POS and Android device to the same Wi-Fi/LAN.
2. In the Windows POS, open **Android customer display** (phone icon).
3. Install and open `CustomerDisplay.apk`.
4. Tap **Scan pairing QR** and scan the code shown by the POS.

The app saves the pairing and reconnects automatically. It only receives and
displays QR/payment status events; it does not create orders or process payments.

## Build

```sh
flutter pub get
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

Release builds use a private `android/key.properties` file containing
`storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. The keystore path
is relative to `android/` (or absolute). Supply the original QR Connect signing
key to update installed companion apps. No signing passwords, keystores or
machine-specific SDK paths were copied from the source project. These files
must remain outside Git. For local development use `flutter run` or
`flutter build apk --debug`.
