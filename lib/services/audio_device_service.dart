import 'package:flutter/services.dart';

class AudioDeviceService {
  static const MethodChannel _channel = MethodChannel('com.example.easymed/audio_devices');

  /// Get list of available audio input devices (microphones)
  static Future<List<AudioInputDevice>> getAvailableMicrophones() async {
    try {
      final List<dynamic> devices = await _channel.invokeMethod('getAudioInputDevices');
      return devices.map((device) => AudioInputDevice.fromMap(device)).toList();
    } catch (e) {
      // Fallback to default if platform channel fails
      return [AudioInputDevice(id: 'default', name: 'Default Microphone')];
    }
  }
}

class AudioInputDevice {
  final String id;
  final String name;

  AudioInputDevice({
    required this.id,
    required this.name,
  });

  factory AudioInputDevice.fromMap(Map<dynamic, dynamic> map) {
    return AudioInputDevice(
      id: map['id'] as String? ?? 'unknown',
      name: map['name'] as String? ?? 'Unknown Device',
    );
  }
}

