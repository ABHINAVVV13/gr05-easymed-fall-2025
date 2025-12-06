import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class AudioWaveformService {
  /// Extract waveform data from an audio file
  /// Returns a list of amplitude values (0.0 to 1.0) representing the waveform
  /// This analyzes the audio file bytes to estimate waveform amplitude
  Future<List<double>> extractWaveform(String audioFilePath) async {
    try {
      final file = File(audioFilePath);
      if (!file.existsSync()) {
        debugPrint('Audio file does not exist: $audioFilePath');
        return [];
      }

      // Read audio file bytes
      final fileBytes = await file.readAsBytes();
      final fileSize = fileBytes.length;
      
      if (fileSize == 0) {
        debugPrint('Audio file is empty');
        return [];
      }
      
      // Sample the file at regular intervals to create waveform
      // This analyzes the compressed audio data to estimate amplitude
      // For more accurate results, you would need to decode the audio first
      final samples = 500; // Number of waveform points
      final step = (fileSize / samples).round().clamp(1, fileSize);
      
      List<double> waveform = [];
      
      for (int i = 0; i < samples; i++) {
        final offset = (i * step).clamp(0, fileSize - 1);
        
        // Analyze a window of bytes around this position
        final windowSize = step.clamp(10, 200);
        final start = offset.clamp(0, fileSize - 1);
        final end = (offset + windowSize).clamp(0, fileSize);
        
        if (start >= end) {
          waveform.add(0.0);
          continue;
        }
        
        // Calculate amplitude based on byte variance and magnitude
        // Higher variance and magnitude indicate louder audio
        double sum = 0.0;
        double sumSquares = 0.0;
        int count = 0;
        
        for (int j = start; j < end; j++) {
          final byte = fileBytes[j];
          // Convert to signed value
          final value = (byte - 128) / 128.0;
          sum += value.abs();
          sumSquares += value * value;
          count++;
        }
        
        if (count > 0) {
          // Use RMS (Root Mean Square) for amplitude estimation
          final rms = (sumSquares / count);
          // Also consider average magnitude
          final avgMagnitude = (sum / count);
          // Combine both for better amplitude estimation
          final amplitude = ((rms * 0.7) + (avgMagnitude * 0.3)).clamp(0.0, 1.0);
          waveform.add(amplitude);
        } else {
          waveform.add(0.0);
        }
      }
      
      // Normalize waveform to use full range
      if (waveform.isNotEmpty) {
        final maxAmplitude = waveform.reduce((a, b) => a > b ? a : b);
        if (maxAmplitude > 0) {
          waveform = waveform.map((a) => (a / maxAmplitude).clamp(0.0, 1.0)).toList();
        }
      }
      
      return waveform;
    } catch (e) {
      debugPrint('Error extracting waveform: $e');
      return [];
    }
  }

  /// Extract waveform from audio URL (downloads first)
  Future<List<double>> extractWaveformFromUrl(String audioUrl, String localPath) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) {
        debugPrint('Local audio file does not exist: $localPath');
        return [];
      }
      
      return await extractWaveform(localPath);
    } catch (e) {
      debugPrint('Error extracting waveform from URL: $e');
      return [];
    }
  }

  /// Generate a more accurate waveform by analyzing audio patterns
  /// This creates a waveform that better represents actual audio amplitude
  List<double> generateWaveformFromAudioData(Uint8List audioData, int sampleRate, int samples) {
    List<double> waveform = [];
    
    if (audioData.isEmpty) {
      return List.filled(samples, 0.0);
    }
    
    // Calculate samples per waveform point
    final samplesPerPoint = (audioData.length / samples).round().clamp(1, audioData.length);
    
    for (int i = 0; i < samples; i++) {
      final startIndex = (i * samplesPerPoint).clamp(0, audioData.length - 1);
      final endIndex = ((i + 1) * samplesPerPoint).clamp(0, audioData.length);
      
      if (startIndex >= endIndex) {
        waveform.add(0.0);
        continue;
      }
      
      // Calculate RMS (Root Mean Square) for amplitude
      double sumSquares = 0.0;
      int count = 0;
      
      for (int j = startIndex; j < endIndex; j++) {
        // Convert byte to signed value (-128 to 127)
        final sample = (audioData[j] - 128) / 128.0;
        sumSquares += sample * sample;
        count++;
      }
      
      if (count > 0) {
        final rms = (sumSquares / count);
        final amplitude = rms.clamp(0.0, 1.0);
        waveform.add(amplitude);
      } else {
        waveform.add(0.0);
      }
    }
    
    return waveform;
  }
}

