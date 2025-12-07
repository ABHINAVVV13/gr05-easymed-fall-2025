import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_sound/flutter_sound.dart' as flutter_sound;
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../models/stethoscope_model.dart';
import '../../services/stethoscope_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/ecg_widget.dart';
import '../../widgets/stethoscope_playback_dialog.dart';
import '../../services/audio_device_service.dart';
import '../../services/appointment_service.dart';

final stethoscopeServiceProvider = Provider<StethoscopeService>((ref) {
  return StethoscopeService();
});

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

final patientRecordingsProvider = StreamProvider.family<List<StethoscopeModel>, String>((ref, patientId) {
  final service = ref.read(stethoscopeServiceProvider);
  return service.getPatientRecordingsStream(patientId);
});

class PatientStethoscopeScreen extends ConsumerStatefulWidget {
  const PatientStethoscopeScreen({super.key});

  @override
  ConsumerState<PatientStethoscopeScreen> createState() => _PatientStethoscopeScreenState();
}

class _PatientStethoscopeScreenState extends ConsumerState<PatientStethoscopeScreen> {
  final flutter_sound.FlutterSoundRecorder _recorder = flutter_sound.FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer(); // Keep for compatibility
  final just_audio.AudioPlayer _justAudioPlayer = just_audio.AudioPlayer(); // Better AAC support
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoadingPlayback = false;
  String? _recordingPath;
  String? _selectedMicrophoneName;
  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  Timer? _recordingTimer;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    // Set player mode to media player (better for music/audio files)
    _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    
    // Listen to audioplayers events (fallback)
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _stopPositionPolling();
            _isPlaying = false;
          }
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _playbackPosition = position;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (duration != null && duration.inSeconds > 0 && mounted) {
        setState(() {
          _playbackDuration = duration;
        });
      }
    });
    
    // Set up just_audio listeners (primary player)
    _justAudioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _playbackPosition = position;
        });
      }
    });
    
    _justAudioPlayer.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() {
          _playbackDuration = duration;
        });
      }
    });
    
    _justAudioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == just_audio.ProcessingState.completed) {
            _isPlaying = false;
            _isLoadingPlayback = false; // Reset loading flag when completed
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    _justAudioPlayer.dispose();
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
    } catch (e) {
      debugPrint('Error initializing recorder: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required')),
          );
        }
        return;
      }

      // Show microphone selection dialog
      final selectedMic = await _showMicrophoneSelectionDialog();
      if (selectedMic == null) {
        return; // User cancelled
      }

      // Check if it's a supported stethoscope
      final isSupported = selectedMic.toLowerCase().contains('eko-stethoscope');
      if (!isSupported) {
        final shouldContinue = await _showUnsupportedStethoscopeDialog(selectedMic);
        if (!shouldContinue) {
          return; // User chose not to record
        }
      }

      // Ensure recorder is open before checking codecs
      try {
        // Try to reopen recorder to ensure it's in a clean state
        try {
          await _recorder.closeRecorder();
        } catch (e) {
          // Ignore if already closed
        }
        await Future.delayed(const Duration(milliseconds: 100));
        await _recorder.openRecorder();
      } catch (e) {
        debugPrint('Error opening recorder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initializing recorder: ${e.toString()}')),
          );
        }
        return;
      }

      // Find a supported codec - try each one
      flutter_sound.Codec? codec;
      // Try simpler codecs first that are more likely to work
      final codecsToTry = [
        flutter_sound.Codec.pcm16WAV,  // Most compatible - WAV format
        flutter_sound.Codec.pcm16,     // Raw PCM
        flutter_sound.Codec.aacADTS,   // AAC
        flutter_sound.Codec.opusOGG,   // Opus
        flutter_sound.Codec.opusCAF,   // Opus CAF (iOS)
        flutter_sound.Codec.flac,      // FLAC
        flutter_sound.Codec.vorbisOGG, // Vorbis
      ];

      // First, check which codecs are supported without trying to record
      List<flutter_sound.Codec> supportedCodecs = [];
      for (final testCodec in codecsToTry) {
        try {
          final isSupported = await _recorder.isEncoderSupported(testCodec);
          if (isSupported) {
            supportedCodecs.add(testCodec);
            debugPrint('Codec $testCodec is supported');
          } else {
            debugPrint('Codec $testCodec is NOT supported');
          }
        } catch (e) {
          debugPrint('Error checking codec $testCodec: $e');
        }
      }

      if (supportedCodecs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No audio codecs are supported on this device. Please check your device settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Now try to actually start recording with supported codecs
      String? recordingPath;
      for (final testCodec in supportedCodecs) {
        try {
          // Ensure recorder is open before each attempt
          try {
            await _recorder.openRecorder();
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {
            debugPrint('Error opening recorder: $e');
            // Continue anyway, might already be open
          }
          
          // Get path with correct extension for this codec
          recordingPath = await _getRecordingPath(testCodec);
          debugPrint('Attempting to record with codec: $testCodec');
          debugPrint('Recording path: $recordingPath');
          
          // Try starting recorder - some codecs might need different parameters
          try {
            // First try with default parameters
            await _recorder.startRecorder(
              toFile: recordingPath,
              codec: testCodec,
            );
          } catch (e1) {
            debugPrint('First attempt failed: $e1');
            // For PCM codecs, try with explicit sample rate and channels
            if (testCodec == flutter_sound.Codec.pcm16WAV || testCodec == flutter_sound.Codec.pcm16) {
              try {
                await _recorder.startRecorder(
                  toFile: recordingPath,
                  codec: testCodec,
                  sampleRate: 44100,
                  numChannels: 1, // Mono
                );
              } catch (e2) {
                debugPrint('Second attempt with sample rate failed: $e2');
                // Try with different sample rate
                try {
                  await _recorder.startRecorder(
                    toFile: recordingPath,
                    codec: testCodec,
                    sampleRate: 16000,
                    numChannels: 1,
                  );
                } catch (e3) {
                  debugPrint('Third attempt with 16kHz failed: $e3');
                  rethrow; // Re-throw to continue to next codec
                }
              }
            } else {
              rethrow; // Re-throw to continue to next codec
            }
          }
          
          // If we get here, the codec works!
          codec = testCodec;
          debugPrint('Successfully started recording with codec: $testCodec');
          break;
        } catch (startError) {
          debugPrint('Failed to start with codec $testCodec: $startError');
          debugPrint('Error type: ${startError.runtimeType}');
          debugPrint('Error details: $startError');
          
          // Make sure recorder is stopped before trying next codec
          try {
            await _recorder.stopRecorder();
          } catch (e) {
            debugPrint('Error stopping recorder: $e');
          }
          // Reset recorder state
          try {
            await _recorder.closeRecorder();
            await Future.delayed(const Duration(milliseconds: 200));
            await _recorder.openRecorder();
          } catch (e) {
            debugPrint('Error resetting recorder: $e');
          }
          continue; // Try next codec
        }
      }

      if (codec == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start recording with any supported codec. Supported codecs: ${supportedCodecs.map((c) => c.toString()).join(", ")}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (mounted && codec != null && recordingPath != null) {
        setState(() {
          _isRecording = true;
          _recordingPath = recordingPath;
          _recordingDuration = Duration.zero;
          _selectedMicrophoneName = selectedMic;
        });
      }

      // Start timer to track recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: ${e.toString()}')),
        );
      }
    }
  }

  Future<String?> _showMicrophoneSelectionDialog() async {
    // Get actual available microphones from device
    final devices = await AudioDeviceService.getAvailableMicrophones();
    
    if (devices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No microphones found')),
        );
      }
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Microphone'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: const Icon(Icons.mic),
                title: Text(device.name),
                subtitle: Text('ID: ${device.id}'),
                onTap: () => Navigator.of(context).pop(device.name),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _showUnsupportedStethoscopeDialog(String microphoneName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsupported Stethoscope'),
        content: Text(
          'The selected microphone "$microphoneName" is not a supported stethoscope.\n\n'
          'Supported stethoscopes contain "eko-stethoscope" in their name.\n\n'
          'Do you want to record anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Record Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stopRecorder();
      _recordingTimer?.cancel();

      if (mounted && path != null) {
        setState(() {
          _isRecording = false;
          _recordingPath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  Future<String> _getRecordingPath([flutter_sound.Codec? codec]) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Ensure directory exists
    final dir = Directory(directory.path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    // Choose extension based on codec
    String extension = 'm4a'; // default
    if (codec != null) {
      switch (codec) {
        case flutter_sound.Codec.pcm16WAV:
          extension = 'wav';
          break;
        case flutter_sound.Codec.pcm16:
          extension = 'pcm';
          break;
        case flutter_sound.Codec.aacADTS:
          extension = 'aac';
          break;
        case flutter_sound.Codec.opusOGG:
          extension = 'ogg';
          break;
        case flutter_sound.Codec.opusCAF:
          extension = 'caf';
          break;
        case flutter_sound.Codec.flac:
          extension = 'flac';
          break;
        case flutter_sound.Codec.vorbisOGG:
          extension = 'ogg';
          break;
        default:
          extension = 'm4a';
      }
    }
    
    final filePath = '${directory.path}/stethoscope_$timestamp.$extension';
    debugPrint('Recording file path: $filePath');
    return filePath;
  }

  Future<void> _playRecording(String? path) async {
    if (path == null || !File(path).existsSync()) {
      debugPrint('Cannot play: path is null or file does not exist');
      return;
    }

    try {
      debugPrint('Playing audio from: $path');
      debugPrint('File exists: ${File(path).existsSync()}');
      debugPrint('File size: ${File(path).lengthSync()} bytes');
      
      // Verify file is valid
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw Exception('File does not exist or is empty');
      }
      
      // Stop any current playback
      await _audioPlayer.stop();
      
      // Set volume to maximum
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Play directly - audioplayers handles preparation
      await _audioPlayer.play(DeviceFileSource(path), volume: 1.0);
      
      debugPrint('Play command sent, waiting for state change...');
      
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error playing recording: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing recording: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _pausePlayback() async {
    await _justAudioPlayer.pause();
    await _audioPlayer.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _stopPlayback() async {
    _stopPositionPolling();
    await _justAudioPlayer.stop();
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
      });
    }
  }
  
  void _startPositionPolling() {
    _stopPositionPolling();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isPlaying || !mounted) {
        timer.cancel();
        return;
      }
      try {
        final position = await _audioPlayer.getCurrentPosition();
        if (position != null && mounted) {
          setState(() {
            _playbackPosition = position;
          });
          debugPrint('Polled position: $position');
        }
      } catch (e) {
        debugPrint('Error polling position: $e');
      }
    });
  }
  
  void _stopPositionPolling() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  Future<void> _uploadRecording() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording to upload')),
      );
      return;
    }

    final currentUser = ref.read(authStateNotifierProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      final service = ref.read(stethoscopeServiceProvider);
      final file = File(_recordingPath!);
      
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Upload file
      final audioUrl = await service.uploadAudioFile(file, currentUser.uid);

      // Create recording document
      final recording = StethoscopeModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: currentUser.uid,
        audioUrl: audioUrl,
        fileName: file.path.split('/').last,
        microphoneName: _selectedMicrophoneName ?? 'Default Microphone',
        recordedAt: DateTime.now(),
        uploadedAt: DateTime.now(),
        durationSeconds: _recordingDuration.inSeconds,
      );

      await service.createRecording(recording);

      // Send notification to doctor (get from most recent appointment)
      try {
        final appointmentService = ref.read(appointmentServiceProvider);
        final appointments = await appointmentService.getPatientAppointments(currentUser.uid);
        if (appointments.isNotEmpty) {
          final recentAppointment = appointments.first;
          final notificationHelper = ref.read(notificationHelperProvider);
          await notificationHelper.notifyStethoscopeUploaded(
            recordingId: recording.id,
            patientId: currentUser.uid,
            doctorId: recentAppointment.doctorId,
          );
        }
      } catch (e) {
        debugPrint('Error sending stethoscope notification: $e');
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset state
        setState(() {
          _recordingPath = null;
          _recordingDuration = Duration.zero;
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading recording: $e')),
        );
      }
    }
  }

  Future<void> _uploadFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      final currentUser = ref.read(authStateNotifierProvider).value;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }

      final service = ref.read(stethoscopeServiceProvider);
      final file = File(filePath);
      
      // Get file duration (simplified - in production, use audio metadata)
      final duration = await _getAudioDuration(filePath);
      
      // Upload file
      final audioUrl = await service.uploadAudioFile(file, currentUser.uid);

      // Create recording document
      final recording = StethoscopeModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: currentUser.uid,
        audioUrl: audioUrl,
        fileName: result.files.single.name,
        recordedAt: DateTime.now(),
        uploadedAt: DateTime.now(),
        durationSeconds: duration.inSeconds,
      );

      await service.createRecording(recording);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio file uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

  Future<Duration> _getAudioDuration(String path) async {
    try {
      final player = just_audio.AudioPlayer();
      await player.setFilePath(path);
      final duration = player.duration ?? Duration.zero;
      await player.dispose();
      return duration;
    } catch (e) {
      return const Duration(seconds: 0);
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateNotifierProvider).value;
    final recordingsAsync = currentUser != null
        ? ref.watch(patientRecordingsProvider(currentUser.uid))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stethoscope'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recording Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Record Heartbeat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Recording Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isRecording && !_isPlaying) ...[
                          ElevatedButton.icon(
                            onPressed: _startRecording,
                            icon: const Icon(Icons.mic),
                            label: const Text('Start Recording'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ] else if (_isRecording) ...[
                          Column(
                            children: [
                              const Icon(Icons.mic, size: 48, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(
                                _formatDuration(_recordingDuration),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _stopRecording,
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop Recording'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    // Upload Recording Button
                    if (_recordingPath != null && !_isRecording) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _uploadRecording,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Upload File Button
                    ElevatedButton.icon(
                      onPressed: _uploadFromFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Past Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Playback Section (if recording exists)
            if (_recordingPath != null && File(_recordingPath!).existsSync()) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Preview Recording',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ECG Widget
                      EcgWidget(
                        isPlaying: _isPlaying,
                        duration: _playbackDuration,
                        position: _playbackPosition,
                      ),
                      const SizedBox(height: 16),
                      // Playback Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _isPlaying ? _pausePlayback : () => _playRecording(_recordingPath),
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
            // Recordings History
            const Text(
              'My Recordings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            recordingsAsync?.when(
              data: (recordings) {
                if (recordings.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No recordings yet'),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recordings.length,
                  itemBuilder: (context, index) {
                    final recording = recordings[index];
                    return _RecordingCard(
                      recording: recording,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => StethoscopePlaybackDialog(
                            recording: recording,
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ) ?? const SizedBox(),
          ],
        ),
      ),
    );
  }

  Future<void> _playRecordingFromUrl(String url) async {
    // Only prevent if we're actively loading a new file
    // Allow restarting or playing different files
    if (_isLoadingPlayback) {
      debugPrint('Playback loading in progress, ignoring duplicate call');
      return;
    }
    
    try {
      _isLoadingPlayback = true;
      
      // Stop any current playback first to allow new playback
      await _justAudioPlayer.stop();
      await _audioPlayer.stop();
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading audio...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      // Note: If you can't hear audio, this might be an emulator issue.
      // Android emulators often have audio problems. Try testing on a real device.

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
      
      // Verify file is valid
      if (localFile.lengthSync() == 0) {
        throw Exception('Downloaded file is empty');
      }
      
      // Stop any current playback first
      await _audioPlayer.stop();
      
      // Wait a moment for stop to complete
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Reset position
      if (mounted) {
        setState(() {
          _playbackPosition = Duration.zero;
          _playbackDuration = Duration.zero;
          _isPlaying = false; // Reset playing state
        });
      }
      
      // Try using just_audio for better AAC support
      try {
        // Configure audio session for proper playback
        await _justAudioPlayer.setAudioSource(
          just_audio.AudioSource.file(localPath),
        );
        
        // Set volume to maximum
        await _justAudioPlayer.setVolume(1.0);
        
        // Ensure audio session is active
        await _justAudioPlayer.setSpeed(1.0);
        
        // Play with just_audio (listeners already set up in _initAudioPlayer)
        await _justAudioPlayer.play();
        debugPrint('Playing with just_audio - file: $localPath');
        debugPrint('Volume set to: 1.0');
      } catch (e) {
        debugPrint('just_audio failed, falling back to audioplayers: $e');
        // Fallback to audioplayers
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setReleaseMode(ReleaseMode.stop);
        await _audioPlayer.setPlaybackRate(1.0);
        await _audioPlayer.setSource(DeviceFileSource(localPath));
        await Future.delayed(const Duration(milliseconds: 500));
        await _audioPlayer.resume();
        _startPositionPolling();
      }
      
      debugPrint('Play command sent for URL playback');
      
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _isLoadingPlayback = false;
        });
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');
      _isLoadingPlayback = false;
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing recording: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _RecordingCard extends StatelessWidget {
  final StethoscopeModel recording;
  final VoidCallback onTap;

  const _RecordingCard({
    required this.recording,
    required this.onTap,
  });

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.audiotrack, color: Colors.red, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(recording.recordedAt),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(recording.recordedAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Duration: ${_formatDuration(recording.durationSeconds)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (recording.microphoneName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Mic: ${recording.microphoneName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

