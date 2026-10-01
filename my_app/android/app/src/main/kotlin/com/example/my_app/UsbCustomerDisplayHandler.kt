package com.example.my_app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Base64
import android.util.Log
import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.Ch34xSerialDriver
import com.hoho.android.usbserial.driver.ProbeTable
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Locale
import org.json.JSONObject
import org.json.JSONTokener

class UsbCustomerDisplayHandler(private val activity: FlutterActivity) {
    private val logTag = "SELFX_USB_DISPLAY"
    private val channelName = "selfx_pos/usb_customer_display"

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(::handleUsbCustomerDisplayCall)
    }

    fun destroy() {
        usbDisplayDestroyed = true
        Thread { synchronized(dqr222SerialLock) { closeDqr222Serial() } }.start()
    }

private fun handleUsbCustomerDisplayCall(
    call: io.flutter.plugin.common.MethodCall,
    result: MethodChannel.Result,
) {
    when (call.method) {
        "getStatus" -> {
            val kind = call.argument<String>("device")?.lowercase(Locale.ROOT)
            val device = findUsbCustomerDisplay(kind)
            if (kind == "dqr222" && device == null) {
                Thread {
                    synchronized(dqr222SerialLock) {
                        if (findUsbCustomerDisplay("dqr222") == null) closeDqr222Serial()
                    }
                }.start()
            }
            result.success(
                mapOf(
                    "connected" to (device != null),
                    "port" to device?.let(::usbDisplayIdentifier),
                    "device" to kind,
                    "permissionGranted" to (device?.let(usbManager::hasPermission) ?: false),
                ),
            )
        }
        "writeDq11Frame" -> {
            val frame = call.argument<ByteArray>("frame")
            if (frame == null || frame.size != DQ11_FRAME_BYTES) {
                result.error(
                    "DQ11_INVALID_FRAME",
                    "DQ11 requires exactly $DQ11_FRAME_BYTES RGB565 bytes.",
                    null,
                )
                return
            }
            withUsbCustomerDisplay("dq11", result) { device ->
                writeUsbSerial(device, DQ11_BAUD_RATE) { port ->
                    var offset = 0
                    while (offset < frame.size) {
                        val end = minOf(offset + USB_WRITE_CHUNK, frame.size)
                        port.write(frame.copyOfRange(offset, end), USB_WRITE_TIMEOUT_MS)
                        offset = end
                    }
                }
                null
            }
        }
        "writeDqr222Commands" -> {
            val commands = call.argument<List<String>>("commands")
            if (commands.isNullOrEmpty() || commands.any { it.contains('\n') || it.contains('\r') }) {
                result.error(
                    "DQR222_INVALID_COMMANDS",
                    "DQR-222 commands must be non-empty single lines.",
                    null,
                )
                return
            }
            withUsbCustomerDisplay("dqr222", result) { device ->
                val response = ByteArrayOutputStream()
                writeUsbSerial(device, DQR222_BAUD_RATE) { port ->
                    // Discard previous batch diagnostics on the warm session.
                    readDqr222Serial(port, 20) { false }
                    var cartImageSent = false
                    var firmwareWait = false
                    val readBuffer = ByteArray(4096)
                    commands.forEach { command ->
                        if (command.startsWith("__cartjpeg**")) {
                            val jpeg = Base64.decode(command.removePrefix("__cartjpeg**"), Base64.DEFAULT)
                            require(jpeg.isNotEmpty() && jpeg.size < 100000) { "Invalid cart JPEG size." }
                            port.write("startsendingfile cart.jpeg ${jpeg.size}\n".toByteArray(Charsets.UTF_8), USB_WRITE_TIMEOUT_MS)
                            Thread.sleep(200)
                            var offset = 0
                            while (offset < jpeg.size) {
                                val end = minOf(offset + 1024, jpeg.size)
                                port.write(jpeg.copyOfRange(offset, end), USB_WRITE_TIMEOUT_MS)
                                Thread.sleep(20)
                                offset = end
                            }
                            Thread.sleep(300)
                            cartImageSent = true
                            return@forEach
                        }
                        port.write((command + "\n").toByteArray(Charsets.UTF_8), USB_WRITE_TIMEOUT_MS)
                        when {
                            command == "play**welcome.mp3" -> Thread.sleep(1800)
                            command.startsWith("WelcomeScreen**") -> {
                                Thread.sleep(1800)
                                firmwareWait = true
                            }
                            command.matches(Regex("^Display.*Screen\\*\\*.*")) -> {
                                Thread.sleep(1200)
                                firmwareWait = true
                            }
                            else -> Thread.sleep(200)
                        }
                        try {
                            val count = port.read(readBuffer, 100)
                            if (count > 0) response.write(readBuffer, 0, count)
                        } catch (_: Throwable) {
                            // Some firmware versions acknowledge only the
                            // final screen command. A completed USB write
                            // still means the display accepted the frame.
                        }
                    }
                    if (!cartImageSent && !firmwareWait) try {
                        val count = port.read(readBuffer, 500)
                        if (count > 0) response.write(readBuffer, 0, count)
                    } catch (_: Throwable) {
                        // Response text is diagnostic and is not required.
                    }
                }
                response.toString(Charsets.UTF_8.name()).trim()
            }
        }
        "readDqr222FileInfo" -> {
            val audio = call.argument<Boolean>("audio") == true
            withUsbCustomerDisplay("dqr222", result) { device ->
                var response = ""
                writeUsbSerial(device, DQR222_BAUD_RATE) { port ->
                    Thread.sleep(2000)
                    readDqr222Serial(port, 250) { false }
                    port.write((if (audio) "fileinfomp3\n" else "fileinfo\n").toByteArray(Charsets.UTF_8), USB_WRITE_TIMEOUT_MS)
                    response = readDqr222FileInfo(port, if (audio) "mp3files" else "images")
                }
                response
            }
        }
        "uploadDqr222Advertisement" -> {
            val audio = call.argument<Boolean>("audio") == true
            val fileKey = if (audio) "mp3files" else "images"
            val infoCommand = if (audio) "fileinfomp3\n" else "fileinfo\n"
            val fileName = call.argument<String>("fileName")?.trim().orEmpty()
            val bytes = call.argument<ByteArray>("bytes")
            val chunkSize = call.argument<Int>("chunkSize") ?: DQR222_MEDIA_CHUNK_BYTES
            val validName = if (audio) {
                fileName in setOf("welcome.mp3", "displayqr.mp3", "success.mp3", "fail.mp3", "cancel.mp3", "pending.mp3")
            } else fileName.matches(Regex("^[A-Za-z0-9_-]+\\.jpeg$", RegexOption.IGNORE_CASE))
            if (!validName) {
                result.error(
                    "DQR222_INVALID_MEDIA_NAME",
                    "Use a simple .jpeg filename, for example 1.jpeg.",
                    null,
                )
                return
            }
            if (bytes == null || bytes.isEmpty() || bytes.size > 1966080 ||
                chunkSize != DQR222_MEDIA_CHUNK_BYTES) {
                result.error(
                    "DQR222_INVALID_MEDIA",
                    "DQR-222 advertisement data must be non-empty and use 1024-byte chunks.",
                    null,
                )
                return
            }
            if (!audio && bytes.size >= 100000) {
                result.error(
                    "DQR222_INVALID_MEDIA",
                    "Advertisement JPEG must be under 100 KB (100,000 bytes).",
                    null,
                )
                return
            }
            withUsbCustomerDisplay("dqr222", result) { device ->
                var beforeFileInfo = ""
                var afterFileInfo = ""
                var acknowledgedChunks = 0
                writeUsbSerial(device, DQR222_BAUD_RATE) { port ->
                    Thread.sleep(2000)
                    readDqr222Serial(port, 250) { false }

                    port.write("stoprotation\n".toByteArray(Charsets.UTF_8), USB_WRITE_TIMEOUT_MS)
                    readDqr222Serial(port, 750) { false }

                    port.write(infoCommand.toByteArray(Charsets.UTF_8), USB_WRITE_TIMEOUT_MS)
                    beforeFileInfo = readDqr222FileInfo(port, fileKey)
                    val before = JSONObject(beforeFileInfo)
                    val images = before.getJSONArray(fileKey)
                    var originalSize: Long? = null
                    for (index in 0 until images.length()) {
                        val entry = images.getJSONObject(index)
                        if (entry.getString("filename") == fileName) {
                            originalSize = entry.getLong("size")
                        }
                    }
                    Log.i(logTag, "DQR-222 media originalSize=$originalSize expectedBytes=${bytes.size}")
                    check(before.getLong("availableBytes") >= bytes.size.toLong()) {
                        "Not enough free display storage for this JPEG."
                    }

                    val uploadCommand =
                        "${if (audio) "sendingaudio" else "sending"}**$fileName**${bytes.size}**$DQR222_MEDIA_CHUNK_BYTES\n"
                    Log.i(logTag, "DQR-222 media command: ${uploadCommand.trim()}")
                    port.write(uploadCommand.toByteArray(Charsets.UTF_8), USB_WRITE_TIMEOUT_MS)
                    readDqr222Serial(port, 500) { false }

                    var offset = 0
                    while (offset < bytes.size) {
                        val end = minOf(offset + DQR222_MEDIA_CHUNK_BYTES, bytes.size)
                        port.write(bytes.copyOfRange(offset, end), USB_WRITE_TIMEOUT_MS)
                        val chunkNumber = acknowledgedChunks + 1
                        val acknowledgement = readDqr222Serial(
                            port,
                            DQR222_MEDIA_ACK_TIMEOUT_MS,
                        ) { value -> DQR222_OK_ACK.containsMatchIn(value) }
                        if (!DQR222_OK_ACK.containsMatchIn(acknowledgement)) {
                            throw IllegalStateException(
                                "DQR-222 did not acknowledge advertisement chunk $chunkNumber.",
                            )
                        }
                        acknowledgedChunks++
                        Log.i(
                            logTag,
                            "DQR-222 media chunk $chunkNumber ACK: ${acknowledgement.trim()}",
                        )
                        offset = end
                    }

                    readDqr222Serial(port, 750) { false }
                    port.write(infoCommand.toByteArray(Charsets.UTF_8), USB_WRITE_TIMEOUT_MS)
                    afterFileInfo = readDqr222FileInfo(port, fileKey)
                    val storedImages = JSONObject(afterFileInfo).getJSONArray(fileKey)
                    var storedSize: Long? = null
                    for (index in 0 until storedImages.length()) {
                        val entry = storedImages.getJSONObject(index)
                        if (entry.getString("filename") == fileName) {
                            storedSize = entry.getLong("size")
                        }
                    }
                    Log.i(logTag, "DQR-222 media finalSize=$storedSize verified=${storedSize == bytes.size.toLong()}")
                    check(storedSize == bytes.size.toLong()) {
                        "DQR-222 stored $storedSize bytes; expected ${bytes.size}."
                    }
                }
                mapOf(
                    "beforeFileInfo" to beforeFileInfo,
                    "afterFileInfo" to afterFileInfo,
                    "chunkCount" to acknowledgedChunks,
                )
            }
        }
        else -> result.notImplemented()
    }
}

private fun readDqr222FileInfo(port: UsbSerialPort, fileKey: String): String {
    var fileInfo: String? = null
    val response = readDqr222Serial(port, DQR222_FILE_INFO_TIMEOUT_MS) { value ->
        val start = Regex("\\{\\s*\"$fileKey\"\\s*:").find(value)?.range?.first
        if (start != null) {
            try {
                val parsed = JSONTokener(value.substring(start)).nextValue() as? JSONObject
                if (parsed?.optJSONArray(fileKey) != null && parsed.has("availableBytes")) {
                    fileInfo = parsed.toString()
                }
            } catch (_: org.json.JSONException) {
                // Wait for the rest of the JSON object.
            }
        }
        fileInfo != null
    }
    return fileInfo ?: throw IllegalStateException("DQR-222 fileinfo response timed out: $response")
}

private fun readDqr222Serial(
    port: UsbSerialPort,
    timeoutMs: Int,
    complete: (String) -> Boolean,
): String {
    val response = ByteArrayOutputStream()
    val buffer = ByteArray(4096)
    val deadline = android.os.SystemClock.elapsedRealtime() + timeoutMs
    while (android.os.SystemClock.elapsedRealtime() < deadline) {
        val remaining = (deadline - android.os.SystemClock.elapsedRealtime()).coerceAtLeast(1L)
            val count = port.read(buffer, minOf(remaining, 200L).toInt())
            if (count > 0) {
                response.write(buffer, 0, count)
                val current = response.toString(Charsets.UTF_8.name())
                if (complete(current)) return current
            }
    }
    return response.toString(Charsets.UTF_8.name())
}

private val usbManager: UsbManager
    get() = activity.getSystemService(Context.USB_SERVICE) as UsbManager

private fun findUsbCustomerDisplay(kind: String?): UsbDevice? {
    val devices = usbManager.deviceList.values
    return when (kind) {
        "dq11" -> devices.firstOrNull {
            it.vendorId == DQ11_VENDOR_ID && it.productId == DQ11_PRODUCT_ID
        }
        "dqr222" -> devices.firstOrNull {
            it.vendorId == DQR222_VENDOR_ID && it.productId == DQR222_PRODUCT_ID
        } ?: devices.singleOrNull {
            it.vendorId == DQR222_CH340_VENDOR_ID &&
                it.productId == DQR222_CH340_PRODUCT_ID
        }
        else -> null
    }
}

private fun usbDisplayIdentifier(device: UsbDevice): String =
    "USB:%04X:%04X:%d".format(
        Locale.US,
        device.vendorId,
        device.productId,
        device.deviceId,
    )

private fun withUsbCustomerDisplay(
    kind: String,
    result: MethodChannel.Result,
    operation: (UsbDevice) -> Any?,
) {
    val device = findUsbCustomerDisplay(kind)
    if (device == null) {
        result.error(
            "USB_DISPLAY_NOT_FOUND",
            "${kind.uppercase(Locale.ROOT)} customer display is not connected.",
            null,
        )
        return
    }

    fun execute() {
        Thread {
            try {
                val value = operation(device)
                activity.runOnUiThread { result.success(value) }
            } catch (error: Throwable) {
                Log.e(logTag, "$kind USB customer display failed", error)
                activity.runOnUiThread {
                    result.error(
                        "USB_DISPLAY_WRITE_FAILED",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }
        }.start()
    }

    if (usbManager.hasPermission(device)) {
        execute()
        return
    }

    val permissionAction = "${activity.packageName}.USB_CUSTOMER_DISPLAY_PERMISSION.${device.deviceId}"
    val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != permissionAction) return
            try {
                activity.unregisterReceiver(this)
            } catch (_: Throwable) {
                // Receiver was already removed during activity teardown.
            }
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            if (granted) {
                execute()
            } else {
                result.error(
                    "USB_PERMISSION_DENIED",
                    "Allow USB access to use the ${kind.uppercase(Locale.ROOT)} customer display.",
                    null,
                )
            }
        }
    }
    val filter = IntentFilter(permissionAction)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
        @Suppress("DEPRECATION")
        activity.registerReceiver(receiver, filter)
    }
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
    } else {
        PendingIntent.FLAG_UPDATE_CURRENT
    }
    val permissionIntent = PendingIntent.getBroadcast(
        activity,
        device.deviceId,
        Intent(permissionAction).setPackage(activity.packageName),
        flags,
    )
    usbManager.requestPermission(device, permissionIntent)
}

private val dqr222SerialLock = Any()
private var dqr222SerialPort: UsbSerialPort? = null
private var dqr222SerialConnection: UsbDeviceConnection? = null
private var dqr222SerialDevice: String? = null
@Volatile private var usbDisplayDestroyed = false

// Called only under dqr222SerialLock, including media operations and teardown.
private fun closeDqr222Serial() {
    try { dqr222SerialPort?.close() } catch (_: Throwable) {}
    try { dqr222SerialConnection?.close() } catch (_: Throwable) {}
    dqr222SerialPort = null
    dqr222SerialConnection = null
    dqr222SerialDevice = null
}

private fun writeDqr222Serial(device: UsbDevice, writer: (UsbSerialPort) -> Unit) {
    synchronized(dqr222SerialLock) {
        check(!usbDisplayDestroyed) { "USB display activity was closed." }
        val identity = usbDisplayIdentifier(device)
        if (dqr222SerialDevice != identity) closeDqr222Serial()
        try {
            if (dqr222SerialPort == null) {
                val port = usbSerialDriver(device)?.ports?.firstOrNull()
                    ?: throw IllegalStateException("No DQR-222 serial port available.")
                val connection = usbManager.openDevice(device)
                    ?: throw IllegalStateException("Android could not open the USB customer display.")
                dqr222SerialConnection = connection
                dqr222SerialPort = port
                port.open(connection)
                port.setParameters(DQR222_BAUD_RATE, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
                dqr222SerialDevice = identity
                // Firmware settling is needed only when opening a new session.
                Thread.sleep(1500)
            }
            writer(dqr222SerialPort!!)
        } catch (error: Throwable) {
            closeDqr222Serial()
            throw error
        }
    }
}

private fun writeUsbSerial(
    device: UsbDevice,
    baudRate: Int,
    writer: (UsbSerialPort) -> Unit,
) {
    if (baudRate == DQR222_BAUD_RATE) {
        writeDqr222Serial(device, writer)
        return
    }
    val driver = usbSerialDriver(device)
        ?: throw IllegalStateException(
            "No Android USB serial driver supports ${usbDisplayIdentifier(device)}.",
        )
    val connection = usbManager.openDevice(device)
        ?: throw IllegalStateException("Android could not open the USB customer display.")
    val port = driver.ports.firstOrNull()
        ?: throw IllegalStateException("The USB customer display has no serial port.")
    try {
        port.open(connection)
        port.setParameters(
            baudRate,
            8,
            UsbSerialPort.STOPBITS_1,
            UsbSerialPort.PARITY_NONE,
        )
        writer(port)
    } finally {
        try {
            port.close()
        } catch (_: Throwable) {
            connection.close()
        }
    }
}

private fun usbSerialDriver(device: UsbDevice): UsbSerialDriver? {
    val table = ProbeTable().apply {
        addProduct(DQ11_VENDOR_ID, DQ11_PRODUCT_ID, CdcAcmSerialDriver::class.java)
        addProduct(DQR222_VENDOR_ID, DQR222_PRODUCT_ID, CdcAcmSerialDriver::class.java)
        addProduct(
            DQR222_CH340_VENDOR_ID,
            DQR222_CH340_PRODUCT_ID,
            Ch34xSerialDriver::class.java,
        )
    }
    return UsbSerialProber(table).probeDevice(device)
        ?: UsbSerialProber.getDefaultProber().probeDevice(device)
}

private companion object {
    const val DQ11_VENDOR_ID = 0x0483
    const val DQ11_PRODUCT_ID = 0x5740
    const val DQ11_BAUD_RATE = 921600
    const val DQ11_FRAME_BYTES = 320 * 480 * 2

    const val DQR222_VENDOR_ID = 0x303A
    const val DQR222_PRODUCT_ID = 0x1001
    const val DQR222_CH340_VENDOR_ID = 0x1A86
    const val DQR222_CH340_PRODUCT_ID = 0x7523
    const val DQR222_BAUD_RATE = 230400
    const val DQR222_MEDIA_CHUNK_BYTES = 1024
    const val DQR222_MEDIA_ACK_TIMEOUT_MS = 5000
    const val DQR222_FILE_INFO_TIMEOUT_MS = 6000
    val DQR222_OK_ACK = Regex("^ok\\r?$", RegexOption.MULTILINE)

    const val USB_WRITE_CHUNK = 16 * 1024
    const val USB_WRITE_TIMEOUT_MS = 15_000
}
}
