import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../models/stethoscope_model.dart';
import '../../models/user_model.dart';
import '../../services/stethoscope_service.dart';
import '../../services/auth_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_waveform_service.dart';

final doctorStethoscopeServiceProvider = Provider<StethoscopeService>((ref) {
  return StethoscopeService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final doctorStethoscopeRecordingsProvider = StreamProvider.family<List<StethoscopeModel>, String>((ref, doctorId) {
  final service = ref.read(doctorStethoscopeServiceProvider);
  return service.getDoctorRecordingsStream(doctorId);
});

class DoctorStethoscopeScreen extends ConsumerStatefulWidget {
  const DoctorStethoscopeScreen({super.key});

  @override
  ConsumerState<DoctorStethoscopeScreen> createState() => _DoctorStethoscopeScreenState();
}

class _DoctorStethoscopeScreenState extends ConsumerState<DoctorStethoscopeScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioWaveformService _waveformService = AudioWaveformService();
  bool _isPlaying = false;
  String? _currentlyPlayingUrl;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  List<double> _waveformData = [];
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    // Set player mode to media player (better for music/audio files)
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _playbackPosition = position;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      debugPrint('Duration changed: $duration');
      if (mounted) {
        setState(() {
          _playbackDuration = duration;
        });
      }
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      debugPrint('Player state changed: $state');
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _isPlaying = false;
            _playbackPosition = Duration.zero;
            _currentlyPlayingUrl = null;
          }
        });
        _playbackTimer?.cancel();
      }
    });
    _audioPlayer.onLog.listen((message) {
      debugPrint('AudioPlayer log: $message');
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _playRecording(String url) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading audio...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Download file to local storage and play (more reliable for AAC)
      final directory = await getApplicationDocumentsDirectory();
      // Extract filename from URL, handling URL encoding
      String fileName = url.split('/').last.split('?').first;
      // Decode URL encoding if present
      try {
        fileName = Uri.decodeComponent(fileName);
      } catch (e) {
        // If decoding fails, use original
        debugPrint('Failed to decode filename: $e');
      }
      // Extract just the filename part (remove any path segments)
      fileName = fileName.split('/').last;
      // Ensure it has a valid extension
      if (!fileName.endsWith('.aac') && !fileName.endsWith('.m4a') && !fileName.endsWith('.mp3')) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      }
      final localPath = '${directory.path}/$fileName';
      final localFile = File(localPath);

      // Download file if it doesn't exist
      if (!localFile.existsSync()) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
        } else {
          throw Exception('Failed to download audio: ${response.statusCode}');
        }
      }

      debugPrint('Playing audio from URL: $url');
      debugPrint('Local file path: $localPath');
      debugPrint('Local file exists: ${localFile.existsSync()}');
      debugPrint('Local file size: ${localFile.lengthSync()} bytes');
      
      // Extract waveform data from audio file
      final waveform = await _waveformService.extractWaveform(localPath);
      if (mounted) {
        setState(() {
          _waveformData = waveform;
        });
      }
      
      // Stop current playback if playing different file
      if (_currentlyPlayingUrl != url) {
        await _audioPlayer.stop();
      }

      // Verify file is valid
      if (localFile.lengthSync() == 0) {
        throw Exception('Downloaded file is empty');
      }
      
      // Set volume to maximum
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Play directly - audioplayers handles preparation
      await _audioPlayer.play(DeviceFileSource(localPath), volume: 1.0);
      
      debugPrint('Play command sent for doctor playback');
      
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _currentlyPlayingUrl = url;
        });
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing recording: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pausePlayback() async {
    await _audioPlayer.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
        _currentlyPlayingUrl = null;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String _formatDurationSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateNotifierProvider).value;
    final recordingsAsync = currentUser != null
        ? ref.watch(doctorStethoscopeRecordingsProvider(currentUser.uid))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Stethoscope Recordings'),
      ),
      body: recordingsAsync?.when(
        data: (recordings) {
          if (recordings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hearing,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No stethoscope recordings available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group recordings by patient
          final Map<String, List<StethoscopeModel>> groupedByPatient = {};
          for (var recording in recordings) {
            if (!groupedByPatient.containsKey(recording.patientId)) {
              groupedByPatient[recording.patientId] = [];
            }
            groupedByPatient[recording.patientId]!.add(recording);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Playback Section (if playing)
              if (_currentlyPlayingUrl != null) ...[
                Card(
                  elevation: 2,
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Now Playing',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Waveform Visualization
                        _buildWaveform(),
                        const SizedBox(height: 16),
                        // Playback Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _isPlaying ? _pausePlayback : () => _playRecording(_currentlyPlayingUrl!),
                              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                              iconSize: 48,
                              color: Colors.blue,
                            ),
                            IconButton(
                              onPressed: _stopPlayback,
                              icon: const Icon(Icons.stop),
                              iconSize: 32,
                              color: Colors.red,
                            ),
                          ],
                        ),
                        // Progress
                        if (_playbackDuration.inSeconds > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_formatDuration(_playbackPosition)} / ${_formatDuration(_playbackDuration)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Recordings by Patient
              ...groupedByPatient.entries.map((entry) {
                return _PatientRecordingsSection(
                  patientId: entry.key,
                  recordings: entry.value,
                  onPlay: (url) => _playRecording(url),
                  currentlyPlayingUrl: _currentlyPlayingUrl,
                  isPlaying: _isPlaying && _currentlyPlayingUrl != null,
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ) ?? const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildWaveform() {
    if (_waveformData.isEmpty) {
      return const SizedBox(height: 80);
    }

    final progress = _playbackDuration.inMilliseconds > 0
        ? (_playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds).clamp(0.0, 1.0)
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

class _PatientRecordingsSection extends ConsumerWidget {
  final String patientId;
  final List<StethoscopeModel> recordings;
  final Function(String) onPlay;
  final String? currentlyPlayingUrl;
  final bool isPlaying;

  const _PatientRecordingsSection({
    required this.patientId,
    required this.recordings,
    required this.onPlay,
    this.currentlyPlayingUrl,
    required this.isPlaying,
  });

  String _formatDurationSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<UserModel?>(
      future: ref.read(authServiceProvider).getUserData(patientId),
      builder: (context, snapshot) {
        final patient = snapshot.data;
        final patientName = patient?.displayName ?? 'Patient';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red,
              child: Text(
                patientName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              patientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${recordings.length} recording${recordings.length != 1 ? 's' : ''}'),
            children: recordings.map((recording) {
              final isCurrentlyPlaying = currentlyPlayingUrl == recording.audioUrl && isPlaying;
              
              return ListTile(
                leading: Icon(
                  isCurrentlyPlaying ? Icons.graphic_eq : Icons.audiotrack,
                  color: isCurrentlyPlaying ? Colors.red : Colors.grey,
                ),
                title: Text(
                  DateFormat('MMM d, yyyy h:mm a').format(recording.recordedAt),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duration: ${_formatDurationSeconds(recording.durationSeconds)}'),
                    if (recording.microphoneName != null)
                      Text('Mic: ${recording.microphoneName}'),
                    if (recording.notes != null)
                      Text('Notes: ${recording.notes}'),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(isCurrentlyPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () => onPlay(recording.audioUrl),
                  color: isCurrentlyPlaying ? Colors.red : Colors.blue,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

