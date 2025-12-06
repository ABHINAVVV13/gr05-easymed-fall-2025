package com.example.easymed

import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.easymed/audio_devices"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAudioInputDevices") {
                val devices = getAudioInputDevices()
                result.success(devices)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getAudioInputDevices(): List<Map<String, String>> {
        val devices = mutableListOf<Map<String, String>>()
        
        try {
            val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val inputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
                for (device in inputDevices) {
                    if (device.type == AudioDeviceInfo.TYPE_BUILTIN_MIC ||
                        device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                        device.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                        device.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                        device.type == AudioDeviceInfo.TYPE_UNKNOWN) {
                        var deviceName = "Unknown Device"
                        
                        // Try to get product name first
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            device.productName?.let {
                                if (it.isNotEmpty()) {
                                    deviceName = it.toString()
                                }
                            }
                        }
                        
                        // If product name is empty, try to get a descriptive name based on type
                        if (deviceName == "Unknown Device" || deviceName.isEmpty()) {
                            deviceName = when (device.type) {
                                AudioDeviceInfo.TYPE_BUILTIN_MIC -> "Built-in Microphone"
                                AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth Headset"
                                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth Audio"
                                AudioDeviceInfo.TYPE_USB_HEADSET -> "USB Headset"
                                AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired Headset"
                                else -> "Audio Input Device"
                            }
                        }
                        
                        val deviceId = device.id.toString()
                        devices.add(mapOf(
                            "id" to deviceId,
                            "name" to deviceName
                        ))
                    }
                }
            }
            
            // If no devices found or API level too low, add default
            if (devices.isEmpty()) {
                devices.add(mapOf(
                    "id" to "default",
                    "name" to "Default Microphone"
                ))
            }
        } catch (e: Exception) {
            // Fallback to default on error
            devices.add(mapOf(
                "id" to "default",
                "name" to "Default Microphone"
            ))
        }
        
        return devices
    }
}
