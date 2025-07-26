import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'services/audio_manager_service.dart';
import 'services/screen_transition_manager.dart';
import 'services/voice_navigation_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late FlutterTts tts;
  late SpeechToText speech;
  late AudioManagerService _audioManagerService;
  late ScreenTransitionManager _screenTransitionManager;
  late VoiceNavigationService _voiceNavigationService;

  StreamSubscription? _audioControlSubscription;
  StreamSubscription? _screenActivationSubscription;
  StreamSubscription? _transitionSubscription;
  StreamSubscription? _voiceStatusSubscription;
  StreamSubscription? _navigationCommandSubscription;
  StreamSubscription? _downloadsCommandSubscription;

  final bool _isVoiceInitialized = false;
  bool _isListening = false;
  String _voiceStatus = 'Initializing...';
  bool _isNarrating = false;

  // Downloads screen specific voice command state
  bool _isDownloadsVoiceEnabled = true;
  bool _isAudioPlaybackMode = false;
  bool _isDownloadManagementMode = false;
  String _lastSpokenTour = '';
  int _commandCount = 0;
  int _currentTourIndex = 0; // Track current tour for next functionality

  // Enhanced playback state
  bool _isPaused = false;
  String _pausedTour = '';
  double _playbackProgress = 0.0;
  Timer? _progressTimer;
  String _currentPlaybackStatus = 'stopped'; // 'playing', 'paused', 'stopped'

  // Audio playback state
  bool _isPlaying = false;
  String? _currentlyPlaying;
  Timer? _playbackTimer;

  final List<Map<String, dynamic>> _downloads = [
    {
      'name': 'Murchison Falls',
      'status': 'Downloaded',
      'size': '45.2 MB',
      'duration': '15:30',
      'description':
          'Explore the magnificent Murchison Falls, one of Uganda\'s most spectacular natural wonders.',
      'audioUrl': 'murchison_falls_audio.mp3',
    },
    {
      'name': 'Kasubi Tombs',
      'status': 'Downloaded',
      'size': '32.1 MB',
      'duration': '12:45',
      'description':
          'Discover the royal tombs of the Buganda kingdom, a UNESCO World Heritage site.',
      'audioUrl': 'kasubi_tombs_audio.mp3',
    },
    {
      'name': 'Bwindi Impenetrable Forest',
      'status': 'Downloading...',
      'size': '67.8 MB',
      'duration': '22:15',
      'description':
          'Experience the mystical Bwindi forest, home to endangered mountain gorillas.',
      'audioUrl': 'bwindi_forest_audio.mp3',
    },
    {
      'name': 'Lake Victoria Tour',
      'status': 'Available',
      'size': '28.9 MB',
      'duration': '18:20',
      'description':
          'Journey around Africa\'s largest lake, exploring its islands and fishing communities.',
      'audioUrl': 'lake_victoria_audio.mp3',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      // Initialize services
      _audioManagerService = AudioManagerService();
      _screenTransitionManager = ScreenTransitionManager();
      _voiceNavigationService = VoiceNavigationService();

      // Initialize TTS and speech recognition
      tts = FlutterTts();
      speech = SpeechToText();

      await _initTTS();
      await _initSpeechToText();
      await _registerWithAudioManager();
      await _initializeVoiceNavigation();
      await _activateDownloadsAudio();
    } catch (e) {
      print('Error initializing downloads screen services: $e');
      setState(() {
        _voiceStatus = 'Error initializing services';
      });
    }
  }

  Future<void> _activateDownloadsAudio() async {
    try {
      // Activate downloads screen audio
      await _audioManagerService.activateScreenAudio('downloads');

      // Start automatic narration
      await _startAutomaticNarration();
    } catch (e) {
      print('Error activating downloads audio: $e');
    }
  }

  Future<void> _startAutomaticNarration() async {
    setState(() {
      _isNarrating = true;
    });

    // Enhanced welcome message with offline content focus
    await _audioManagerService.speakIfActive(
      'downloads',
      "Welcome to your Offline Content Library! Here you can access all your downloaded tours and audio guides without needing internet. I'll help you explore, play, and manage your offline content with simple voice commands.",
    );

    // Brief pause for user to process
    await Future.delayed(Duration(seconds: 1));

    // Narrate available downloads with enhanced descriptions
    await _speakAvailableDownloads();

    setState(() {
      _isNarrating = false;
    });
  }

  Future<void> _speakAvailableDownloads() async {
    int downloadedCount =
        _downloads.where((d) => d['status'] == 'Downloaded').length;
    int availableCount =
        _downloads.where((d) => d['status'] == 'Available').length;

    String downloadList =
        "You have $downloadedCount offline tours ready to play and $availableCount available for download. ";

    for (int i = 0; i < _downloads.length; i++) {
      final download = _downloads[i];
      String status =
          download['status'] == 'Downloaded'
              ? 'ready to play'
              : download['status'];
      downloadList +=
          "${i + 1}. ${download['name']}, $status, ${download['duration']}. ${download['description']} ";
    }

    downloadList +=
        "Say 'one' through 'four' to select and play specific tours, 'play' to start current tour, 'pause' to pause, 'next' for next tour, 'previous' for previous tour, 'repeat' to hear again, or 'go back' to return.";

    await _audioManagerService.speakIfActive('downloads', downloadList);
  }

  Future<void> _initTTS() async {
    try {
      await tts.setLanguage("en-US");
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
    } catch (e) {
      developer.log("TTS Init Error: $e", name: 'TTS');
    }
  }

  Future<void> _initSpeechToText() async {
    try {
      bool available = await speech.initialize(
        onError: (error) {
          developer.log("STT Error: ${error.errorMsg}", name: 'SpeechToText');
        },
        onStatus: (status) {
          developer.log("STT Status: $status", name: 'SpeechToText');
        },
      );
      if (available) {
        developer.log("STT Available", name: 'SpeechToText');
      }
    } catch (e) {
      developer.log("STT Init Error: $e", name: 'SpeechToText');
    }
  }

  Future<void> _registerWithAudioManager() async {
    _audioManagerService.registerScreen('downloads', tts, speech);

    _audioControlSubscription = _audioManagerService.audioControlStream.listen((
      event,
    ) {
      print('Downloads screen audio control event: $event');
    });

    _screenActivationSubscription = _audioManagerService.screenActivationStream
        .listen((screenId) {
          print('Downloads screen activation event: $screenId');
        });

    _transitionSubscription = _screenTransitionManager.transitionStream.listen((
      event,
    ) {
      print('Downloads screen transition event: $event');
    });
  }

  Future<void> _initializeVoiceNavigation() async {
    // Listen to downloads-specific voice commands
    _downloadsCommandSubscription = _voiceNavigationService
        .downloadsCommandStream
        .listen((command) {
          _handleDownloadsVoiceCommand(command);
        });

    // Listen to voice status updates
    _voiceStatusSubscription = _voiceNavigationService.voiceStatusStream.listen(
      (status) {
        setState(() {
          _voiceStatus = status;
          if (status.startsWith('listening_started')) {
            _isListening = true;
          } else if (status.startsWith('listening_stopped')) {
            _isListening = false;
          }
        });
      },
    );

    // Listen to navigation commands
    _navigationCommandSubscription = _voiceNavigationService
        .navigationCommandStream
        .listen((command) {
          print('Downloads screen navigation command: $command');
          _handleNavigationCommand(command);
        });

    // Listen to navigation commands for tour actions
    _voiceNavigationService.navigationCommandStream.listen((command) {
      print('Downloads screen tour command: $command');
      _handleTourCommand(command);
    });
  }

  void _handleNavigationCommand(String command) {
    if (command.startsWith('navigated:')) {
      String screen = command.split(':')[1];
      if (screen == 'downloads') {
        // We're now on downloads screen, activate audio
        _activateDownloadsAudio();
      }
    } else if (command == 'back') {
      _navigateBack();
    }
  }

  void _handleTourCommand(String command) {
    if (command.startsWith('play_tour:')) {
      String tourName = command.split(':')[1];
      _playTour(tourName);
    } else if (command == 'stop_tour') {
      _stopPlayback();
    } else if (command == 'download_all') {
      _downloadAll();
    } else if (command == 'delete_downloads') {
      _deleteDownloads();
    }
  }

  // Handle downloads-specific voice commands
  Future<void> _handleDownloadsVoiceCommand(String command) async {
    print('🎤 Downloads voice command received: $command');

    // Limit command frequency to prevent spam
    if (_commandCount > 10) {
      _commandCount = 0;
      return;
    }
    _commandCount++;

    // Simple number commands for quick access to specific tours
    if (command == 'one' || command == '1' || command == 'first') {
      await _playTourByNumber(0);
    } else if (command == 'two' || command == '2' || command == 'second') {
      await _playTourByNumber(1);
    } else if (command == 'three' || command == '3' || command == 'third') {
      await _playTourByNumber(2);
    } else if (command == 'four' || command == '4' || command == 'fourth') {
      await _playTourByNumber(3);
    } else if (command.startsWith('play_tour:')) {
      String tourName = command.split(':').last;
      await _handlePlayTourCommand(tourName);
    } else if (command == 'play' ||
        command == 'start' ||
        command == 'start tour') {
      await _handlePlayCurrentTourCommand();
    } else if (command == 'stop_tour' || command == 'stop') {
      await _handleStopTourCommand();
    } else if (command == 'pause_tour' ||
        command == 'pause' ||
        command == 'pause tour') {
      await _handlePauseTourCommand();
    } else if (command == 'resume' ||
        command == 'resume tour' ||
        command == 'continue') {
      await _resumePlayback();
    } else if (command.startsWith('playback_control:')) {
      String action = command.split(':').last;
      await _handlePlaybackControlCommand(action);
    } else if (command == 'playback_status' || command == 'what is playing') {
      await _handlePlaybackStatusCommand();
    } else if (command.startsWith('volume_control:')) {
      String action = command.split(':').last;
      await _handleVolumeControlCommand(action);
    } else if (command.startsWith('speed_control:')) {
      String action = command.split(':').last;
      await _handleSpeedControlCommand(action);
    } else if (command == 'download_all' || command == 'download all') {
      await _handleDownloadAllCommand();
    } else if (command == 'delete_downloads' || command == 'delete downloads') {
      await _handleDeleteDownloadsCommand();
    } else if (command == 'show_downloads' || command == 'list downloads') {
      await _speakAvailableDownloads();
    } else if (command == 'next' || command == 'next tour') {
      await _nextTour();
    } else if (command == 'previous' || command == 'previous tour') {
      await _previousTour();
    } else if (command == 'repeat' || command == 'read all') {
      await _speakAvailableDownloads();
    } else if (command == 'stop talking' || command == 'pause narration') {
      await _audioManagerService.stopAllAudio();
    } else if (command == 'resume talking' || command == 'continue narration') {
      await _speakAvailableDownloads();
    } else if (command == 'go back' || command == 'back') {
      await _navigateBack();
    } else if (command.startsWith('help')) {
      await _handleDownloadsHelpCommand();
    } else {
      // Unknown command - provide helpful feedback
      await _audioManagerService.speakIfActive(
        'downloads',
        "Say 'one' through 'four' to select and play specific tours, 'play' to start current tour, 'pause' to pause, 'next' for next tour, 'previous' for previous tour, 'repeat' to hear options again, or 'go back' to return.",
      );
    }
  }

  Future<void> _playTourByNumber(int index) async {
    if (index >= 0 && index < _downloads.length) {
      _currentTourIndex = index;
      final tour = _downloads[index];

      if (tour['status'] == 'Downloaded') {
        await _audioManagerService.speakIfActive(
          'downloads',
          "Selected ${tour['name']}. ${tour['description']} Say 'play' to start, 'pause' to pause, 'next' for next tour, 'previous' for previous tour, or 'repeat' to hear options again.",
        );
        _playTour(tour['name']);
      } else {
        await _audioManagerService.speakIfActive(
          'downloads',
          "${tour['name']} is ${tour['status']}. Say 'download all' to get all tours, or select another tour with 'one' through 'four'.",
        );
      }
    } else {
      await _audioManagerService.speakIfActive(
        'downloads',
        "Tour number ${index + 1} not available. Say 'repeat' to see options.",
      );
    }
  }

  // Downloads command handlers
  Future<void> _handlePlayCurrentTourCommand() async {
    if (_currentTourIndex >= 0 && _currentTourIndex < _downloads.length) {
      final tour = _downloads[_currentTourIndex];
      await _audioManagerService.speakIfActive(
        'downloads',
        "Playing ${tour['name']}. ${tour['description']}",
      );
      _playTour(tour['name']);
    } else {
      await _audioManagerService.speakIfActive(
        'downloads',
        "No tour selected. Say 'one' through 'four' to select a tour first.",
      );
    }
  }

  Future<void> _handlePlayTourCommand(String tourName) async {
    await _audioManagerService.speakIfActive('downloads', "Playing $tourName.");
    _playTour(tourName);
  }

  Future<void> _handleStopTourCommand() async {
    await _audioManagerService.speakIfActive('downloads', "Stopped.");
    _stopPlayback();
  }

  Future<void> _handleDownloadAllCommand() async {
    await _audioManagerService.speakIfActive(
      'downloads',
      "Downloading all tours.",
    );
    _downloadAll();
  }

  Future<void> _handleDeleteDownloadsCommand() async {
    await _audioManagerService.speakIfActive(
      'downloads',
      "Deleting downloads.",
    );
    _deleteDownloads();
  }

  Future<void> _handleDownloadsHelpCommand() async {
    await _audioManagerService.speakIfActive(
      'downloads',
      "Downloads commands: 'one' through 'four' for specific tours, 'play' to start, 'pause' to pause, 'stop' to stop, 'repeat' to hear again, 'download all' to get all tours, 'go back' to return.",
    );
  }

  Future<void> _handlePauseTourCommand() async {
    if (_isPlaying && _currentlyPlaying != null) {
      _pausePlayback();
      await _audioManagerService.speakIfActive(
        'downloads',
        "Tour paused. Say 'play' to resume, 'next' for next tour, 'previous' for previous tour, or 'repeat' to hear options.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'downloads',
        "No tour is currently playing. Say 'one' through 'four' to select a tour, or 'repeat' to hear options.",
      );
    }
  }

  Future<void> _handlePlaybackControlCommand(String action) async {
    if (action == 'next') {
      await _playNextTour();
    } else if (action == 'previous') {
      await _playPreviousTour();
    }
  }

  Future<void> _handlePlaybackStatusCommand() async {
    if (_isPlaying && _currentlyPlaying != null) {
      await _audioManagerService.speakIfActive(
        'downloads',
        "Playing $_currentlyPlaying. ${(_playbackProgress * 100).toStringAsFixed(0)}% done.",
      );
    } else if (_isPaused && _pausedTour.isNotEmpty) {
      await _audioManagerService.speakIfActive(
        'downloads',
        "Paused: $_pausedTour. Say 'resume' to continue.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'downloads',
        "Nothing playing. Say 'one', 'two', 'three', 'four' to start.",
      );
    }
  }

  Future<void> _handleVolumeControlCommand(String action) async {
    switch (action) {
      case 'up':
        await _audioManagerService.speakIfActive('downloads', "Volume up.");
        break;
      case 'down':
        await _audioManagerService.speakIfActive('downloads', "Volume down.");
        break;
      case 'mute':
        await _audioManagerService.speakIfActive(
          'downloads',
          "Muted. Say 'unmute' to restore.",
        );
        break;
      case 'unmute':
        await _audioManagerService.speakIfActive('downloads', "Unmuted.");
        break;
    }
  }

  Future<void> _handleSpeedControlCommand(String action) async {
    switch (action) {
      case 'up':
        await _audioManagerService.speakIfActive('downloads', "Speed up.");
        break;
      case 'down':
        await _audioManagerService.speakIfActive('downloads', "Speed down.");
        break;
      case 'normal':
        await _audioManagerService.speakIfActive('downloads', "Normal speed.");
        break;
    }
  }

  Future<void> _navigateBack() async {
    await _audioManagerService.speakIfActive(
      'downloads',
      "Going back to previous screen.",
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // User control methods for next/previous tour navigation
  Future<void> _nextTour() async {
    _currentTourIndex = (_currentTourIndex + 1) % _downloads.length;
    final tour = _downloads[_currentTourIndex];

    if (tour['status'] == 'Downloaded') {
      await _audioManagerService.speakIfActive(
        'downloads',
        "Next tour: ${tour['name']}. ${tour['description']}. Say 'play' to start, 'next' for next tour, 'previous' for previous tour, or 'repeat' to hear options.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'downloads',
        "Next tour: ${tour['name']} is ${tour['status']}. Say 'play' to start if available, 'next' for next tour, 'previous' for previous tour, or 'repeat' to hear options.",
      );
    }
  }

  Future<void> _previousTour() async {
    _currentTourIndex =
        (_currentTourIndex - 1 + _downloads.length) % _downloads.length;
    final tour = _downloads[_currentTourIndex];

    if (tour['status'] == 'Downloaded') {
      await _audioManagerService.speakIfActive(
        'downloads',
        "Previous tour: ${tour['name']}. ${tour['description']}. Say 'play' to start, 'next' for next tour, 'previous' for previous tour, or 'repeat' to hear options.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'downloads',
        "Previous tour: ${tour['name']} is ${tour['status']}. Say 'play' to start if available, 'next' for next tour, 'previous' for previous tour, or 'repeat' to hear options.",
      );
    }
  }

  // Audio playback methods
  Future<void> _playTour(String tourName) async {
    final tour = _downloads.firstWhere(
      (d) => d['name'].toLowerCase().contains(tourName.toLowerCase()),
      orElse: () => _downloads[0],
    );

    if (tour['status'] != 'Downloaded') {
      await _audioManagerService.speakIfActive(
        'downloads',
        "${tour['name']} is not downloaded yet. Please download it first.",
      );
      return;
    }

    // Stop any current playback
    _playbackTimer?.cancel();
    _progressTimer?.cancel();

    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _currentlyPlaying = tour['name'];
      _pausedTour = '';
      _playbackProgress = 0.0;
      _currentPlaybackStatus = 'playing';
    });

    await _audioManagerService.speakIfActive(
      'downloads',
      "Now playing ${tour['name']}. ${tour['description']}",
    );

    // Start progress tracking
    _startPlaybackProgress();

    // Simulate audio playback with longer duration
    _playbackTimer = Timer(Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlaying = null;
          _playbackProgress = 0.0;
          _currentPlaybackStatus = 'stopped';
        });
        _audioManagerService.speakIfActive(
          'downloads',
          "Tour playback completed. Say 'play another tour' or 'go back' to return to home.",
        );
      }
    });
  }

  Future<void> _stopPlayback() async {
    _playbackTimer?.cancel();
    _progressTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _currentlyPlaying = null;
      _pausedTour = '';
      _playbackProgress = 0.0;
      _currentPlaybackStatus = 'stopped';
    });
    await _audioManagerService.speakIfActive('downloads', "Playback stopped.");
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    _progressTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _isPaused = true;
      _pausedTour = _currentlyPlaying ?? '';
      _currentPlaybackStatus = 'paused';
    });
  }

  Future<void> _resumePlayback() async {
    if (_isPaused && _pausedTour.isNotEmpty) {
      setState(() {
        _isPlaying = true;
        _isPaused = false;
        _currentlyPlaying = _pausedTour;
        _pausedTour = '';
        _currentPlaybackStatus = 'playing';
      });

      await _audioManagerService.speakIfActive(
        'downloads',
        "Resuming playback of $_currentlyPlaying.",
      );

      _startPlaybackProgress();
    }
  }

  Future<void> _playNextTour() async {
    if (_currentlyPlaying != null) {
      int currentIndex = _downloads.indexWhere(
        (d) => d['name'] == _currentlyPlaying,
      );
      if (currentIndex != -1 && currentIndex < _downloads.length - 1) {
        String nextTour = _downloads[currentIndex + 1]['name'];
        await _playTour(nextTour);
      } else {
        await _audioManagerService.speakIfActive(
          'downloads',
          "No more tours available. This is the last tour in the list.",
        );
      }
    } else {
      await _audioManagerService.speakIfActive(
        'downloads',
        "No tour is currently playing. Say 'play tour' followed by tour name to start.",
      );
    }
  }

  Future<void> _playPreviousTour() async {
    if (_currentlyPlaying != null) {
      int currentIndex = _downloads.indexWhere(
        (d) => d['name'] == _currentlyPlaying,
      );
      if (currentIndex > 0) {
        String previousTour = _downloads[currentIndex - 1]['name'];
        await _playTour(previousTour);
      } else {
        await _audioManagerService.speakIfActive(
          'downloads',
          "No previous tours available. This is the first tour in the list.",
        );
      }
    } else {
      await _audioManagerService.speakIfActive(
        'downloads',
        "No tour is currently playing. Say 'play tour' followed by tour name to start.",
      );
    }
  }

  void _startPlaybackProgress() {
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          _playbackProgress = (_playbackProgress + 0.01).clamp(0.0, 1.0);
        });

        if (_playbackProgress >= 1.0) {
          timer.cancel();
          _stopPlayback();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _downloadAll() async {
    await _audioManagerService.speakIfActive(
      'downloads',
      "Starting download of all available content. This may take a few minutes.",
    );

    // Simulate download process
    for (int i = 0; i < _downloads.length; i++) {
      if (_downloads[i]['status'] == 'Available') {
        setState(() {
          _downloads[i]['status'] = 'Downloading...';
        });

        await Future.delayed(Duration(seconds: 2));

        setState(() {
          _downloads[i]['status'] = 'Downloaded';
        });
      }
    }

    await _audioManagerService.speakIfActive(
      'downloads',
      "All downloads completed successfully. You can now play any tour by saying 'one' through 'four' or 'play tour' followed by the tour name.",
    );
  }

  Future<void> _deleteDownloads() async {
    await _audioManagerService.speakIfActive(
      'downloads',
      "Deleting all downloaded content. This will free up storage space.",
    );

    setState(() {
      for (int i = 0; i < _downloads.length; i++) {
        if (_downloads[i]['status'] == 'Downloaded') {
          _downloads[i]['status'] = 'Available';
        }
      }
    });

    await _audioManagerService.speakIfActive(
      'downloads',
      "All downloads have been deleted. Content is still available for re-download.",
    );
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _progressTimer?.cancel();
    tts.stop();
    speech.stop();
    _audioControlSubscription?.cancel();
    _screenActivationSubscription?.cancel();
    _transitionSubscription?.cancel();
    _voiceStatusSubscription?.cancel();
    _navigationCommandSubscription?.cancel();
    _downloadsCommandSubscription?.cancel();
    _audioManagerService.unregisterScreen('downloads');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Offline Downloads"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isNarrating ? Icons.volume_off : Icons.volume_up),
            onPressed: () {
              if (_isNarrating) {
                _audioManagerService.stopAllAudio();
                setState(() {
                  _isNarrating = false;
                });
              } else {
                _speakAvailableDownloads();
              }
            },
            tooltip: _isNarrating ? 'Stop Narration' : 'Start Narration',
          ),
          IconButton(
            icon: Icon(Icons.home),
            onPressed: _navigateBack,
            tooltip: 'Go Home',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator and control panel
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  _isNarrating ? Icons.record_voice_over : Icons.volume_up,
                  color: _isNarrating ? Colors.green : Colors.white70,
                  size: 24,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPaused
                        ? "Paused - Tour ${_currentTourIndex + 1}"
                        : _isNarrating
                        ? "Narrating offline content..."
                        : "Tap downloads or use voice commands",
                    style: TextStyle(
                      color:
                          _isPaused
                              ? Colors.orange
                              : _isNarrating
                              ? Colors.green
                              : Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
                Row(
                  children: [
                    // Pause/Play button
                    IconButton(
                      onPressed: () async {
                        if (_isPaused) {
                          await _resumePlayback();
                        } else {
                          _pausePlayback();
                        }
                      },
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: _isPaused ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      tooltip: _isPaused ? 'Play' : 'Pause',
                    ),
                    // Next button
                    IconButton(
                      onPressed: () async {
                        await _nextTour();
                      },
                      icon: Icon(Icons.skip_next, color: Colors.blue, size: 24),
                      tooltip: 'Next Tour',
                    ),
                    // Previous button
                    IconButton(
                      onPressed: () async {
                        await _previousTour();
                      },
                      icon: Icon(
                        Icons.skip_previous,
                        color: Colors.blue,
                        size: 24,
                      ),
                      tooltip: 'Previous Tour',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.download),
                        label: Text("Download All"),
                        onPressed: _downloadAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.delete),
                        label: Text("Delete All"),
                        onPressed: _deleteDownloads,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isPlaying || _isPaused) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.skip_previous),
                          label: Text("Previous"),
                          onPressed: _playPreviousTour,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                          ),
                          label: Text(_isPaused ? "Resume" : "Pause"),
                          onPressed:
                              _isPaused ? _resumePlayback : _pausePlayback,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isPaused ? Colors.green : Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.skip_next),
                          label: Text("Next"),
                          onPressed: _playNextTour,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Downloads list
          Expanded(
            child: ListView.builder(
              itemCount: _downloads.length,
              itemBuilder: (context, index) {
                final download = _downloads[index];
                final isCurrentlyPlaying =
                    _currentlyPlaying == download['name'];

                return Card(
                  color:
                      isCurrentlyPlaying
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.grey[900],
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      download['name']!,
                      style: TextStyle(
                        color: isCurrentlyPlaying ? Colors.blue : Colors.white,
                        fontWeight:
                            isCurrentlyPlaying
                                ? FontWeight.bold
                                : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(
                          "${download['status']} • ${download['size']} • ${download['duration']}",
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          download['description']!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Say '${index + 1 == 1
                              ? 'one'
                              : index + 1 == 2
                              ? 'two'
                              : index + 1 == 3
                              ? 'three'
                              : 'four'}' or 'play ${download['name']}' to start",
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (isCurrentlyPlaying)
                          Text(
                            "Now playing...",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (download['status'] == 'Downloading...')
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          )
                        else if (download['status'] == 'Downloaded')
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isPaused && _pausedTour == download['name'])
                                IconButton(
                                  icon: Icon(
                                    Icons.play_arrow,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _resumePlayback(),
                                )
                              else if (isCurrentlyPlaying)
                                IconButton(
                                  icon: Icon(Icons.pause, color: Colors.orange),
                                  onPressed: () => _pausePlayback(),
                                )
                              else
                                IconButton(
                                  icon: Icon(
                                    Icons.play_arrow,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _playTour(download['name']),
                                ),
                              if (isCurrentlyPlaying)
                                IconButton(
                                  icon: Icon(Icons.stop, color: Colors.red),
                                  onPressed: () => _stopPlayback(),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Voice control tips
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Text(
                  "Voice Commands",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Say 'one' through 'four' to select and play specific tours • 'play' to start current tour • 'pause' to pause • 'next' for next tour • 'previous' for previous tour • 'repeat' to hear options • 'go back' to return",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
