import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/stethoscope_model.dart';
import '../services/audio_waveform_service.dart';

class StethoscopePlaybackDialog extends StatefulWidget {
  final StethoscopeModel recording;

  const StethoscopePlaybackDialog({
    super.key,
    required this.recording,
  });

  @override
  State<StethoscopePlaybackDialog> createState() => _StethoscopePlaybackDialogState();
}

class _StethoscopePlaybackDialogState extends State<StethoscopePlaybackDialog> {
  final just_audio.AudioPlayer _audioPlayer = just_audio.AudioPlayer();
  final AudioWaveformService _waveformService = AudioWaveformService();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  List<double> _waveformData = [];
  List<double> _ecgWaveformData = [];
  String? _localAudioPath;
  Timer? _waveformTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadAudioAndExtractWaveform();
  }

  void _initPlayer() {
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == just_audio.ProcessingState.completed) {
            _isPlaying = false;
            _position = Duration.zero;
          }
        });
      }
    });
  }

  Future<void> _loadAudio() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Download file to local storage
      final directory = await getApplicationDocumentsDirectory();
      String fileName = widget.recording.audioUrl.split('/').last.split('?').first;
      try {
        fileName = Uri.decodeComponent(fileName);
      } catch (e) {
        // If decoding fails, use original
      }
      fileName = fileName.split('/').last;
      if (!fileName.endsWith('.aac') && !fileName.endsWith('.m4a') && !fileName.endsWith('.mp3')) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      }
      final localPath = '${directory.path}/$fileName';
      final localFile = File(localPath);

      if (!localFile.existsSync()) {
        final response = await http.get(Uri.parse(widget.recording.audioUrl));
        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to download audio: ${response.statusCode}');
        }
      }

      // Use the already downloaded file path
      final path = _localAudioPath ?? localPath;
      await _audioPlayer.setAudioSource(just_audio.AudioSource.file(path));
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAudioAndExtractWaveform() async {
    try {
      // Download file to local storage first
      final directory = await getApplicationDocumentsDirectory();
      String fileName = widget.recording.audioUrl.split('/').last.split('?').first;
      try {
        fileName = Uri.decodeComponent(fileName);
      } catch (e) {
        // If decoding fails, use original
      }
      fileName = fileName.split('/').last;
      if (!fileName.endsWith('.aac') && !fileName.endsWith('.m4a') && !fileName.endsWith('.mp3')) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      }
      final localPath = '${directory.path}/$fileName';
      _localAudioPath = localPath;
      final localFile = File(localPath);

      if (!localFile.existsSync()) {
        final response = await http.get(Uri.parse(widget.recording.audioUrl));
        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to download audio: ${response.statusCode}');
        }
      }

      // Extract actual waveform data from the audio file
      final waveform = await _waveformService.extractWaveform(localPath);
      
      if (mounted) {
        setState(() {
          _waveformData = waveform;
          _ecgWaveformData = waveform; // Use same data for ECG
        });
      }
    } catch (e) {
      debugPrint('Error loading waveform: $e');
      // Fallback to generated waveform
      _generateFallbackWaveform();
    }
  }

  void _generateFallbackWaveform() {
    final duration = widget.recording.durationSeconds;
    final samples = (duration * 10).clamp(50, 500).toInt();
    
    _waveformData = List.generate(samples, (index) {
      final t = index / samples;
      double amplitude = 0.3 + 0.7 * (0.5 + 0.5 * (t * 10 % 1 < 0.5 ? 1 : 0.3));
      amplitude *= (1.0 + 0.3 * (t * 7 % 1 - 0.5).abs());
      return amplitude.clamp(0.1, 1.0);
    });
    
    _ecgWaveformData = _waveformData;
  }

  Future<void> _togglePlayback() async {
    if (_isLoading) return;

    if (_audioPlayer.processingState == just_audio.ProcessingState.idle) {
      await _loadAudio();
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveformTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.audiotrack, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM d, yyyy').format(widget.recording.recordedAt),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('h:mm a').format(widget.recording.recordedAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Waveform Visualization
                  _buildWaveform(),
                  const SizedBox(height: 16),
                  
                  // Time Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Progress Slider
                  Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (value) {
                      if (_duration.inMilliseconds > 0) {
                        _seekTo(Duration(
                          milliseconds: (value * _duration.inMilliseconds).round(),
                        ));
                      }
                    },
                    activeColor: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  
                  // Play/Pause Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 64,
                        icon: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        onPressed: _isLoading ? null : _togglePlayback,
                      ),
                    ],
                  ),
                  
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    if (_waveformData.isEmpty) {
      return const SizedBox(height: 80);
    }

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final currentIndex = (progress * _waveformData.length).round().clamp(0, _waveformData.length - 1);

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: WaveformPainter(
          waveformData: _waveformData,
          progress: progress,
          currentIndex: currentIndex,
        ),
        child: Container(),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final int currentIndex;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.currentIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barWidth = size.width / waveformData.length;
    final maxHeight = size.height * 0.8;

    for (int i = 0; i < waveformData.length; i++) {
      final amplitude = waveformData[i];
      final barHeight = amplitude * maxHeight;
      final x = i * barWidth + barWidth / 2;
      final startY = centerY - barHeight / 2;
      final endY = centerY + barHeight / 2;

      final currentPaint = i <= currentIndex ? progressPaint : paint;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.currentIndex != currentIndex;
  }
}

