import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

class EcgWidget extends StatefulWidget {
  final bool isPlaying;
  final Duration? duration;
  final Duration? position;
  final just_audio.AudioPlayer? audioPlayer;
  final List<double>? waveformData; // Actual audio waveform data

  const EcgWidget({
    super.key,
    required this.isPlaying,
    this.duration,
    this.position,
    this.audioPlayer,
    this.waveformData,
  });

  @override
  State<EcgWidget> createState() => _EcgWidgetState();
}

class _EcgWidgetState extends State<EcgWidget> {
  Timer? _timer;
  final List<ChartData> _dataPoints = [];
  double _currentTime = 0.0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(EcgWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If waveform data changed, reinitialize
    if (widget.waveformData != oldWidget.waveformData) {
      _initializeData();
    }
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
    if (widget.position != oldWidget.position) {
      _updateTime(widget.position);
    }
  }

  @override
  void dispose() {
    _stopAnimation();
    super.dispose();
  }

  void _initializeData() {
    _dataPoints.clear();
    // Use actual waveform data if available, otherwise generate synthetic
    if (widget.waveformData != null && widget.waveformData!.isNotEmpty) {
      // Use ACTUAL audio waveform data
      final waveformData = widget.waveformData!;
      final dataPoints = 500;
      final duration = widget.duration?.inSeconds ?? 10.0;
      
      for (int i = 0; i < dataPoints; i++) {
        // Map index to waveform data
        final waveformIndex = ((i / dataPoints) * waveformData.length).round().clamp(0, waveformData.length - 1);
        final amplitude = waveformData[waveformIndex];
        // Direct audio data: 0.0-1.0 amplitude -> -1.0 to 1.0 for display
        final value = (amplitude - 0.5) * 2.0;
        _dataPoints.add(ChartData(i.toDouble(), value));
      }
    } else {
      // Fallback to synthetic only if no waveform data
      final dataPoints = 500;
      final timeWindow = 10.0;
      for (int i = 0; i < dataPoints; i++) {
        final t = (i / dataPoints) * timeWindow;
        final value = _generateEcgValueForTime(t);
        _dataPoints.add(ChartData(i.toDouble(), value));
      }
    }
  }


  void _startAnimation() {
    _timer?.cancel();
    // Immediately update with current position
    if (widget.position != null) {
      _updateEcgForPosition(widget.position!.inMilliseconds / 1000.0);
    }
    // Update frequently to show real-time audio data
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && widget.isPlaying) {
        if (widget.position != null) {
          // Use actual playback position - this updates the waveform in real-time
          final currentTime = widget.position!.inMilliseconds / 1000.0;
          setState(() {
            _currentTime = currentTime;
            _updateEcgForPosition(currentTime);
          });
        } else {
          // Fallback to timer-based animation
          setState(() {
            _currentTime += 0.05;
            _updateEcgForPosition(_currentTime);
          });
        }
      }
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateTime(Duration? position) {
    if (position != null) {
      final newTime = position.inMilliseconds / 1000.0;
      // Always update to show real-time audio data - no threshold check
      if (mounted) {
        setState(() {
          _currentTime = newTime;
          // Update ECG data based on actual playback position - this makes it dynamic
          _updateEcgForPosition(newTime);
        });
      }
    }
  }

  void _updateEcgForPosition(double timeInSeconds) {
    // Use actual waveform data if available, otherwise generate synthetic ECG
    if (widget.waveformData != null && widget.waveformData!.isNotEmpty && widget.duration != null) {
      _updateEcgFromWaveform(timeInSeconds);
    } else {
      _updateEcgSynthetic(timeInSeconds);
    }
  }

  void _updateEcgFromWaveform(double timeInSeconds) {
    // Use actual audio waveform data directly - this IS the audio data visualization
    final waveformData = widget.waveformData!;
    final duration = widget.duration!.inSeconds;
    final dataPoints = 500;
    final timeWindow = 10.0; // Show 10 seconds of ECG data
    final startTime = (timeInSeconds - timeWindow / 2).clamp(0.0, duration);
    
    _dataPoints.clear();
    for (int i = 0; i < dataPoints; i++) {
      final t = startTime + (i / dataPoints) * timeWindow;
      if (t >= 0 && t <= duration && waveformData.isNotEmpty) {
        // Map time to waveform index - this is the ACTUAL audio data
        final waveformIndex = ((t / duration) * waveformData.length).round().clamp(0, waveformData.length - 1);
        // Use the actual waveform amplitude directly
        // Transform to center around 0 for ECG display (amplitude 0.0-1.0 -> -1.0 to 1.0)
        final amplitude = waveformData[waveformIndex];
        // Direct mapping: 0.0 amplitude = -1.0, 1.0 amplitude = 1.0, 0.5 = 0.0
        final value = (amplitude - 0.5) * 2.0;
        _dataPoints.add(ChartData(i.toDouble(), value));
      } else {
        _dataPoints.add(ChartData(i.toDouble(), 0.0));
      }
    }
  }

  void _updateEcgSynthetic(double timeInSeconds) {
    // Fallback to synthetic ECG if no waveform data
    final dataPoints = 500;
    final timeWindow = 10.0;
    final startTime = (timeInSeconds - timeWindow / 2).clamp(0.0, double.infinity);
    
    _dataPoints.clear();
    for (int i = 0; i < dataPoints; i++) {
      final t = startTime + (i / dataPoints) * timeWindow;
      final value = _generateEcgValueForTime(t);
      _dataPoints.add(ChartData(i.toDouble(), value));
    }
  }

  double _generateEcgValueForTime(double timeInSeconds) {
    // Generate ECG pattern based on actual time
    // Heart rate ~60-100 BPM, so beats every ~0.6-1.0 seconds
    final heartRate = 72.0; // beats per minute
    final beatInterval = 60.0 / heartRate;
    final beatPosition = (timeInSeconds % beatInterval) / beatInterval;
    
    double value = 0.0;
    
    // QRS complex pattern
    if (beatPosition < 0.05) {
      // Q wave
      value = -0.3 * sin(beatPosition * pi / 0.05 * 10);
    } else if (beatPosition < 0.15) {
      // R wave (sharp spike)
      value = 1.5 * sin((beatPosition - 0.05) * pi / 0.1 * 10);
    } else if (beatPosition < 0.2) {
      // S wave
      value = -0.5 * sin((beatPosition - 0.15) * pi / 0.05 * 10);
    } else if (beatPosition < 0.4) {
      // T wave
      value = 0.3 * sin((beatPosition - 0.2) * pi / 0.2 * 5);
    }
    
    // Add subtle noise
    value += (_random.nextDouble() - 0.5) * 0.05;
    
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: SfCartesianChart(
        plotAreaBackgroundColor: Colors.black,
        primaryXAxis: NumericAxis(
          isVisible: false,
        ),
        primaryYAxis: NumericAxis(
          isVisible: false,
          minimum: -2,
          maximum: 2,
        ),
        series: <LineSeries<ChartData, double>>[
          LineSeries<ChartData, double>(
            dataSource: _dataPoints,
            xValueMapper: (ChartData data, _) => data.x,
            yValueMapper: (ChartData data, _) => data.y,
            color: Colors.green,
            width: 2,
            animationDuration: 0,
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final double x;
  final double y;

  ChartData(this.x, this.y);
}

