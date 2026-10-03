The iMin customer LCD SDK `freeimagelibrary-4-v1.3_2310241200.jar`
and ARM `libfree_image.so` libraries under `src/main/jniLibs` come from
iMin's official ScreenD1Demo-250813 package:
https://oss-sg.imin.sg/docs/demo/D1%2CD1%20Pro%2CFalcon%201%20CustomerDisplay.rar

API documentation: https://oss-sg.imin.sg/docs/en/CustomerDisplay.html

`imin-screen-sdk-v1.3.jar` is an identical renamed copy (same SHA256).
Gradle excludes that copy to avoid duplicate classes in release APKs.

These control the D1 / D1 Pro / Falcon customer LCD through ILcdManager.
The TVS/ZCS SDK handles its own LCD; Android Presentation handles full
secondary Android screens. The iMin native libraries support ARM only.

Built-in printing on NM2 Pro (Android model I21M01) uses SPI through
`iminPrinterSDK-14_V1.3.1_2408141540.jar` and `libserial_port_imin.so` (ARM32/ARM64).
These were extracted from iMin's official SDK and its bundled demo source:
https://imin-sg-resources.oss-ap-southeast-1.aliyuncs.com/docs/demo/iMinPrinter_SDK1.0/iMinPrinterDemo-v1.3.1.zip

Documentation: https://oss-sg.imin.sg/docs/en/Printer.html
SDK 1.x supports Android 11 and below. SDK 2.x is for Android 13 and above.
