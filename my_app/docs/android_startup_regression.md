# Android launch crash (5.5.0)

The 5.5.0+60057 release installs but exits before Flutter renders. Reproduced
with its signed x86_64 release APK on an Android emulator. Logcat reports:

```text
Unable to instantiate activity ComponentInfo{in.selfx.pos/in.selfx.pos.MainActivity}
Caused by: java.lang.IllegalStateException:
System services not available to Activities before onCreate()
```

`MainActivity` eagerly constructed `ScaleSerialHandler(this)` in a property
initializer. That handler immediately requests `USB_SERVICE`, before Android
attaches the Activity context. Create the handler lazily on its first method
channel call instead. During `onDestroy`, close it only if it was initialized;
cleanup must not initialize unused hardware.

## Release regression check

Use a disposable emulator or test device. This installs the APK as an update
and force-stops/relaunches only `in.selfx.pos` three times, without clearing data.

```powershell
.\scripts\test-android-startup.ps1 -ApkPath <signed-release.apk> -DeviceId <adb-device-id>
```

The check requires the process to survive and the POS Activity to remain resumed
ten seconds after each launch. Also inspect the rendered screen and logcat:

```powershell
adb -s <adb-device-id> logcat -d -b crash
```

A successful build or APK signature verification alone does not detect this
Activity lifecycle regression. Test the signed release APK at runtime.
