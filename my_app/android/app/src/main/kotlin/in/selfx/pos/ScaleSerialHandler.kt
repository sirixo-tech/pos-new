package `in`.selfx.pos

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Locale

/**
 * USB serial scale. Uses the same usb-serial-for-android drivers as the
 * customer display: CH34x, CP210x, FTDI, PL2303, and CDC.
 */
class ScaleSerialHandler(private val activity: MainActivity) {
    private val usbManager = activity.getSystemService(Context.USB_SERVICE) as UsbManager
    private val pending = ByteArrayOutputStream()
    private val lock = Any()
    private var port: UsbSerialPort? = null
    private var connection: UsbDeviceConnection? = null
    private var reader: Thread? = null
    @Volatile private var running = false
    private var permissionReceiver: BroadcastReceiver? = null

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "listPorts" -> {
                result.success(listPorts())
                return true
            }
            "open" -> {
                val name = call.argument<String>("name")?.trim().orEmpty()
                val baud = call.argument<Int>("baud") ?: 9600
                val dataBits = call.argument<Int>("dataBits") ?: 8
                val parity = call.argument<String>("parity") ?: "none"
                open(name, baud, dataBits, parity, result)
                return true
            }
            "write" -> {
                val bytes = call.argument<ByteArray>("bytes")
                write(bytes, result)
                return true
            }
            "read" -> {
                result.success(takePending())
                return true
            }
            "close" -> {
                close()
                result.success(null)
                return true
            }
        }
        return false
    }

    fun close() {
        running = false
        val thread = reader
        reader = null
        try {
            thread?.join(300)
        } catch (_: InterruptedException) {
        }
        try {
            port?.close()
        } catch (_: Throwable) {
        }
        try {
            connection?.close()
        } catch (_: Throwable) {
        }
        port = null
        connection = null
        synchronized(lock) { pending.reset() }
        unregisterPermission()
    }

    private fun listPorts(): List<Map<String, String>> {
        return usbManager.deviceList.values.mapNotNull { device ->
            if (probe(device) == null) return@mapNotNull null
            val label = try {
                device.productName?.takeIf { it.isNotBlank() }
            } catch (_: SecurityException) {
                null
            } ?: "USB scale"
            mapOf("name" to device.deviceName, "label" to label)
        }
    }

    private fun open(
        name: String,
        baud: Int,
        dataBits: Int,
        parity: String,
        result: MethodChannel.Result,
    ) {
        val device = usbManager.deviceList.values.firstOrNull { it.deviceName == name }
        if (device == null) {
            result.error("SCALE_OPEN", "That scale is no longer connected.", null)
            return
        }
        if (probe(device) == null) {
            result.error(
                "SCALE_OPEN",
                "This USB device does not speak serial. Use the scale's USB or COM port.",
                null,
            )
            return
        }
        if (usbManager.hasPermission(device)) {
            openPort(device, baud, dataBits, parity, result)
            return
        }
        requestPermission(device) { granted ->
            if (!granted) {
                result.error(
                    "SCALE_PERMISSION",
                    "Allow USB access so the POS can read the scale.",
                    null,
                )
                return@requestPermission
            }
            openPort(device, baud, dataBits, parity, result)
        }
    }

    private fun openPort(
        device: UsbDevice,
        baud: Int,
        dataBits: Int,
        parity: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                close()
                val driver = probe(device)
                    ?: throw IllegalStateException("No serial driver for this scale.")
                val opened = usbManager.openDevice(device)
                    ?: throw IllegalStateException("Android could not open the scale.")
                val serial = driver.ports.firstOrNull()
                    ?: throw IllegalStateException("The scale has no serial port.")
                serial.open(opened)
                serial.setParameters(baud, byteSize(dataBits), UsbSerialPort.STOPBITS_1, parityOf(parity))
                try {
                    serial.setDTR(true)
                    serial.setRTS(true)
                } catch (_: Throwable) {
                }
                port = serial
                connection = opened
                running = true
                val thread = Thread {
                    val buffer = ByteArray(256)
                    while (running) {
                        val count = try {
                            serial.read(buffer, 80)
                        } catch (_: Throwable) {
                            if (running) break
                            0
                        }
                        if (count > 0) append(buffer, count)
                    }
                }
                thread.name = "pos-scale"
                reader = thread
                thread.start()
                activity.runOnUiThread { result.success(null) }
            } catch (error: Throwable) {
                Log.e("ScaleSerial", "open failed", error)
                close()
                activity.runOnUiThread {
                    result.error(
                        "SCALE_OPEN",
                        error.message ?: "Could not open the scale.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun write(bytes: ByteArray?, result: MethodChannel.Result) {
        val serial = port
        if (serial == null) {
            result.error("SCALE_WRITE", "The scale is not connected.", null)
            return
        }
        if (bytes == null || bytes.isEmpty()) {
            result.success(null)
            return
        }
        Thread {
            try {
                serial.write(bytes, 200)
                activity.runOnUiThread { result.success(null) }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    result.error(
                        "SCALE_WRITE",
                        error.message ?: "Could not write to the scale.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun append(buffer: ByteArray, count: Int) {
        synchronized(lock) {
            pending.write(buffer, 0, count)
            if (pending.size() > 8192) {
                val all = pending.toByteArray()
                val kept = all.copyOfRange(all.size - 4096, all.size)
                pending.reset()
                pending.write(kept)
            }
        }
    }

    private fun takePending(): ByteArray {
        synchronized(lock) {
            val bytes = pending.toByteArray()
            pending.reset()
            return bytes
        }
    }

    private fun requestPermission(device: UsbDevice, done: (Boolean) -> Unit) {
        unregisterPermission()
        val action = "${activity.packageName}.USB_SCALE_PERMISSION.${device.deviceId}"
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != action) return
                unregisterPermission()
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                done(granted)
            }
        }
        permissionReceiver = receiver
        val filter = IntentFilter(action)
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
        val pendingIntent = PendingIntent.getBroadcast(
            activity,
            7100 + device.deviceId,
            Intent(action).setPackage(activity.packageName),
            flags,
        )
        usbManager.requestPermission(device, pendingIntent)
    }

    private fun unregisterPermission() {
        val receiver = permissionReceiver ?: return
        permissionReceiver = null
        try {
            activity.unregisterReceiver(receiver)
        } catch (_: Throwable) {
        }
    }

    private fun probe(device: UsbDevice): UsbSerialDriver? {
        UsbSerialProber.getDefaultProber().probeDevice(device)?.let { return it }
        for (index in 0 until device.interfaceCount) {
            val intf = device.getInterface(index)
            if (intf.interfaceClass == UsbConstants.USB_CLASS_COMM) {
                return CdcAcmSerialDriver(device)
            }
        }
        return null
    }

    private fun byteSize(bits: Int): Int {
        return if (bits == 7) UsbSerialPort.DATABITS_7 else UsbSerialPort.DATABITS_8
    }

    private fun parityOf(parity: String): Int {
        return when (parity.lowercase(Locale.US)) {
            "even" -> UsbSerialPort.PARITY_EVEN
            "odd" -> UsbSerialPort.PARITY_ODD
            else -> UsbSerialPort.PARITY_NONE
        }
    }
}
