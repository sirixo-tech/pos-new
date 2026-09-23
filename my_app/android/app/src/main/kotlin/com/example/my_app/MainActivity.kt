package com.example.my_app

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.InputDevice
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var usbDisplays: UsbCustomerDisplayHandler? = null
    private var smartPosDisplay: SmartPosCustomerDisplayHandler? = null
    private var iminScannerReceiver: BroadcastReceiver? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val smartPosPrinter = SmartPosPrinterHandler(mainHandler)
    private var bluetoothPermResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val displays = UsbCustomerDisplayHandler(this)
        displays.register(flutterEngine)
        usbDisplays = displays
        val dualScreen = SmartPosCustomerDisplayHandler(this, mainHandler)
        smartPosDisplay = dualScreen

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pos_main/imin_scanner",
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    stopIminScannerListener()
                    if (!isIminDevice()) return
                    val receiver =
                        object : BroadcastReceiver() {
                            override fun onReceive(context: Context?, intent: Intent?) {
                                if (intent?.action != "com.imin.scanner.api.RESULT_ACTION") return
                                val extras = intent.extras ?: return
                                @Suppress("DEPRECATION")
                                val payload =
                                    listOf("decode_data_str", "decode_data")
                                        .mapNotNull { key ->
                                            when (val value = extras.get(key)) {
                                                is String -> value
                                                is ByteArray -> value.toString(Charsets.UTF_8)
                                                else -> null
                                            }
                                        }.firstOrNull { it.isNotBlank() } ?: return
                                events.success(payload.trimEnd('\u0000', '\r', '\n'))
                            }
                        }
                    val filter = IntentFilter("com.imin.scanner.api.RESULT_ACTION")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                    } else {
                        @Suppress("DEPRECATION")
                        registerReceiver(receiver, filter)
                    }
                    iminScannerReceiver = receiver
                }

                override fun onCancel(arguments: Any?) {
                    stopIminScannerListener()
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pos_main/scanner_status",
        ).setMethodCallHandler { call, result ->
            handleScannerStatus(call.method, result)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "selfx_pos/scanner_status",
        ).setMethodCallHandler { call, result ->
            handleScannerStatus(call.method, result)
        }

        val soundHandler = MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "playTone", "playClick", "playClickSound", "playAlert" -> {
                    val tone = call.argument<String>("tone")
                    result.success(playDeviceTone(tone))
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pos_main/device_sound",
        ).setMethodCallHandler(soundHandler)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "selfx_pos/device_sound",
        ).setMethodCallHandler(soundHandler)

        val smartPosHandler = MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "getUsbPaperStatus" -> {
                    val vendor = call.argument<String>("vendorId")?.toIntOrNull()
                    val product = call.argument<String>("productId")?.toIntOrNull()
                    Thread {
                        var status: Int? = null
                        try {
                            val usbManager = getSystemService(USB_SERVICE) as UsbManager
                            val matches =
                                usbManager.deviceList.values.filter {
                                    vendor != null &&
                                        product != null &&
                                        it.vendorId == vendor &&
                                        it.productId == product
                                }
                            val device = matches.singleOrNull()
                            if (device != null && usbManager.hasPermission(device)) {
                                val connection = usbManager.openDevice(device)
                                if (connection != null) {
                                    try {
                                        for (index in 0 until device.interfaceCount) {
                                            val iface = device.getInterface(index)
                                            if (iface.interfaceClass != UsbConstants.USB_CLASS_PRINTER) {
                                                continue
                                            }
                                            val reply = ByteArray(1)
                                            val count =
                                                connection.controlTransfer(
                                                    0xA1,
                                                    1,
                                                    0,
                                                    iface.id,
                                                    reply,
                                                    1,
                                                    500,
                                                )
                                            if (count == 1) {
                                                status = reply[0].toInt() and 0xff
                                                break
                                            }
                                        }
                                    } finally {
                                        connection.close()
                                    }
                                }
                            }
                        } catch (error: Throwable) {
                            Log.d("POS", "USB paper status unavailable", error)
                        }
                        mainHandler.post { result.success(status) }
                    }.start()
                }
                else -> {
                    if (!smartPosPrinter.handle(call, result)) {
                        result.notImplemented()
                    }
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pos_main/smartpos_printer",
        ).setMethodCallHandler(smartPosHandler)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "selfx_pos/smartpos_printer",
        ).setMethodCallHandler(smartPosHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pos_dual_screen")
            .setMethodCallHandler { call, result ->
                if (!dualScreen.handle(call, result)) {
                    result.notImplemented()
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pos_main/bluetooth",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensurePermissions" -> ensureBluetoothPermissions(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        stopIminScannerListener()
        usbDisplays?.destroy()
        usbDisplays = null
        smartPosDisplay?.destroy()
        smartPosDisplay = null
        super.onDestroy()
    }

    private fun stopIminScannerListener() {
        val receiver = iminScannerReceiver ?: return
        try {
            unregisterReceiver(receiver)
        } catch (_: Throwable) {
        }
        iminScannerReceiver = null
    }

    private fun isIminDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER.orEmpty().lowercase()
        val brand = Build.BRAND.orEmpty().lowercase()
        val model = Build.MODEL.orEmpty().lowercase()
        return listOf(manufacturer, brand, model).any { it.contains("imin") }
    }

    private fun handleScannerStatus(method: String, result: MethodChannel.Result) {
        if (method != "getStatus") {
            result.notImplemented()
            return
        }
        val scannerCount = connectedScannerCount()
        result.success(
            mapOf(
                "connected" to (scannerCount > 0),
                "deviceCount" to scannerCount,
                "hasHardwareKeyboard" to hasHardwareKeyboard(),
            ),
        )
    }

    private fun hasHardwareKeyboard(): Boolean {
        return resources.configuration.keyboard ==
            android.content.res.Configuration.KEYBOARD_QWERTY
    }

    private fun connectedScannerCount(): Int {
        val scannerTerms = listOf(
            "scanner",
            "barcode",
            "honeywell",
            "zebra",
            "symbol",
            "datalogic",
            "newland",
            "imager",
            "sunmi",
            "imin",
        )
        val inputScannerIds = InputDevice.getDeviceIds().filter { id ->
            val device = InputDevice.getDevice(id) ?: return@filter false
            val name = device.name.lowercase(Locale.US)
            val namedScanner = scannerTerms.any(name::contains)
            val externalKeyboard =
                device.isExternal &&
                    !device.isVirtual &&
                    (device.sources and InputDevice.SOURCE_KEYBOARD) != 0 &&
                    device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC
            namedScanner || externalKeyboard
        }
        if (inputScannerIds.isNotEmpty()) return inputScannerIds.size

        val usbManager = getSystemService(USB_SERVICE) as UsbManager
        return usbManager.deviceList.values.count { device ->
            val name = "${device.productName.orEmpty()} ${device.manufacturerName.orEmpty()}"
                .lowercase(Locale.US)
            val namedScanner = scannerTerms.any(name::contains)
            val keyboardHid = (0 until device.interfaceCount).any { index ->
                val usbInterface = device.getInterface(index)
                usbInterface.interfaceClass == UsbConstants.USB_CLASS_HID &&
                    usbInterface.interfaceProtocol == 1
            }
            namedScanner || keyboardHid
        }
    }

    private fun playDeviceTone(toneName: String?): Boolean {
        val durationMs = when (toneName) {
            "pos-beep", "soft_tap", "haptic_tick", "accept" -> 90
            else -> 320
        }
        val toneType = when (toneName) {
            "bell", "ready", "new_order", "modern_chime" -> ToneGenerator.TONE_PROP_ACK
            "accept", "pos-beep", "soft_tap", "haptic_tick" -> ToneGenerator.TONE_PROP_BEEP
            else -> ToneGenerator.TONE_PROP_BEEP2
        }
        val streams = intArrayOf(
            AudioManager.STREAM_MUSIC,
            AudioManager.STREAM_NOTIFICATION,
            AudioManager.STREAM_ALARM,
        )
        for (stream in streams) {
            try {
                val generator = ToneGenerator(stream, 100)
                val started = generator.startTone(toneType, durationMs)
                if (started) {
                    mainHandler.postDelayed({ generator.release() }, (durationMs + 80).toLong())
                    return true
                }
                generator.release()
            } catch (_: Throwable) {
            }
        }
        return try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            ringtone?.play()
            ringtone != null
        } catch (_: Throwable) {
            false
        }
    }

    private fun bluetoothPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        }
    }

    private fun hasBluetoothAccess(): Boolean {
        return bluetoothPermissions().all { permission ->
            ContextCompat.checkSelfPermission(this, permission) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun ensureBluetoothPermissions(result: MethodChannel.Result) {
        if (hasBluetoothAccess()) {
            result.success(true)
            return
        }
        bluetoothPermResult?.success(false)
        bluetoothPermResult = result
        ActivityCompat.requestPermissions(this, bluetoothPermissions(), REQUEST_BLUETOOTH)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_BLUETOOTH) return
        val pending = bluetoothPermResult ?: return
        bluetoothPermResult = null
        pending.success(hasBluetoothAccess())
    }

    companion object {
        private const val REQUEST_BLUETOOTH = 4811
    }
}
