import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'services/audio_manager_service.dart';
import 'services/screen_transition_manager.dart';
import 'services/voice_navigation_service.dart';

class HelpAndSupportScreen extends StatefulWidget {
  const HelpAndSupportScreen({super.key});

  @override
  State<HelpAndSupportScreen> createState() => _HelpAndSupportScreenState();
}

class _HelpAndSupportScreenState extends State<HelpAndSupportScreen> {
  late FlutterTts tts;
  late SpeechToText speech;
  late AudioManagerService _audioManagerService;
  late ScreenTransitionManager _screenTransitionManager;
  late VoiceNavigationService _voiceNavigationService;

  StreamSubscription? _audioControlSubscription;
  StreamSubscription? _screenActivationSubscription;
  StreamSubscription? _transitionSubscription;
  StreamSubscription? _helpCommandSubscription;

  // Help screen specific voice command state
  bool _isHelpVoiceEnabled = true;
  bool _isHelpMode = false;
  int _commandCount = 0;
  bool _isNarrating = false;
  int _currentTopicIndex = 0; // Track current topic for next functionality
  bool _isPaused = false; // Track pause state

  final List<Map<String, String>> _helpTopics = [
    {
      'title': 'Quick Navigation',
      'description': 'Navigate between screens instantly',
      'commands':
          'Say "explore" for map, "discover" for tours, "my content" for downloads',
    },
    {
      'title': 'Map Exploration',
      'description': 'Discover amazing places around you',
      'commands':
          'Say "discover" to start tour, "next" to continue, "tell me more" for details',
    },
    {
      'title': 'Tour Discovery',
      'description': 'Find and start fascinating tours',
      'commands':
          'Say "discover" to find tours, "one" through "four" to select, "start tour" to begin',
    },
    {
      'title': 'My Content',
      'description': 'Access your saved adventures',
      'commands':
          'Say "play tour" to start, "pause" to stop, "resume" to continue, "download all"',
    },
    {
      'title': 'Voice Control',
      'description': 'Control narration and audio',
      'commands':
          'Say "stop talking" to pause, "resume talking" to continue, "repeat" to hear again',
    },
    {
      'title': 'Quick Help',
      'description': 'Get immediate assistance',
      'commands':
          'Say "assistance" anytime, "go back" to return, "home" to go home',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initServices();
    _initTTS();
    _initSpeechToText();
    _registerWithAudioManager();
    _startAutomaticNarration();
  }

  Future<void> _initServices() async {
    _audioManagerService = AudioManagerService();
    _screenTransitionManager = ScreenTransitionManager();
    _voiceNavigationService = VoiceNavigationService();
  }

  Future<void> _initTTS() async {
    tts = FlutterTts();
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
    speech = SpeechToText();
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
    _audioManagerService.registerScreen('help', tts, speech);

    _audioControlSubscription = _audioManagerService.audioControlStream.listen((
      event,
    ) {
      print('Help screen audio control event: $event');
    });

    _screenActivationSubscription = _audioManagerService.screenActivationStream
        .listen((screenId) {
          print('Help screen activation event: $screenId');
        });

    _transitionSubscription = _screenTransitionManager.transitionStream.listen((
      event,
    ) {
      print('Help screen transition event: $event');
    });

    // Listen to help-specific voice commands
    _helpCommandSubscription = _voiceNavigationService.helpCommandStream.listen(
      (command) {
        _handleHelpVoiceCommand(command);
      },
    );
  }

  Future<void> _startAutomaticNarration() async {
    setState(() {
      _isNarrating = true;
    });

    // Interactive welcome with immediate engagement
    await _audioManagerService.speakIfActive(
      'help',
      "Welcome to your interactive assistance guide! I'm here to help you master EchoPath with smooth, intuitive control. Let me show you how to navigate, explore, and discover amazing experiences.",
    );

    // Brief pause for user to process
    await Future.delayed(Duration(seconds: 1));

    // Present interactive assistance options
    await _speakAssistanceOptions();

    setState(() {
      _isNarrating = false;
    });
  }

  Future<void> _speakAssistanceOptions() async {
    String assistance = "Here's your interactive assistance menu: ";
    assistance +=
        "I can help you with quick navigation, map exploration, tour discovery, content management, voice control, and immediate assistance. ";
    assistance +=
        "Say 'one' through 'six' for specific help topics, 'pause' to stop, 'play' to continue, 'next' for next topic, 'previous' for previous topic, or 'go back' to return. ";
    assistance +=
        "You can also say 'repeat' to hear this again, or 'help' for more options.";

    await _audioManagerService.speakIfActive('help', assistance);
  }

  Future<void> _speakAllTopics() async {
    String allTopics = "Here are your interactive assistance options: ";
    for (int i = 0; i < _helpTopics.length; i++) {
      final topic = _helpTopics[i];
      allTopics +=
          "${i + 1}. ${topic['title']}: ${topic['description']}. ${topic['commands']}. ";
    }
    allTopics +=
        "Say 'one' through 'six' for specific help, 'pause' to stop, 'play' to continue, 'next' for next topic, 'previous' for previous topic, or 'go back' to return.";

    await _audioManagerService.speakIfActive('help', allTopics);
  }

  Future<void> _speakTopicDetails(int index) async {
    if (index >= 0 && index < _helpTopics.length) {
      final topic = _helpTopics[index];
      String message =
          "${topic['title']}: ${topic['description']}. ${topic['commands']}. ";
      message +=
          "Say 'pause' to stop, 'play' to continue, 'next' for next topic, 'previous' for previous topic, 'repeat' to hear again, or 'go back' to return.";

      await _audioManagerService.speakIfActive('help', message);
    }
  }

  // Handle help-specific voice commands with enhanced interactivity
  Future<void> _handleHelpVoiceCommand(String command) async {
    print('🎤 Help voice command received: $command');

    // Limit command frequency to prevent spam
    if (_commandCount > 8) {
      _commandCount = 0;
      await _audioManagerService.speakIfActive(
        'help',
        "Too many commands. Please wait a moment before speaking again.",
      );
      return;
    }
    _commandCount++;

    // Interactive topic selection
    if (command == 'one' || command == '1' || command == 'first') {
      _currentTopicIndex = 0;
      await _speakTopicDetails(0);
    } else if (command == 'two' || command == '2' || command == 'second') {
      _currentTopicIndex = 1;
      await _speakTopicDetails(1);
    } else if (command == 'three' || command == '3' || command == 'third') {
      _currentTopicIndex = 2;
      await _speakTopicDetails(2);
    } else if (command == 'four' || command == '4' || command == 'fourth') {
      _currentTopicIndex = 3;
      await _speakTopicDetails(3);
    } else if (command == 'five' || command == '5' || command == 'fifth') {
      _currentTopicIndex = 4;
      await _speakTopicDetails(4);
    } else if (command == 'six' || command == '6' || command == 'sixth') {
      _currentTopicIndex = 5;
      await _speakTopicDetails(5);
    } else if (command == 'pause' ||
        command == 'stop talking' ||
        command == 'stop') {
      await _pauseNarration();
    } else if (command == 'play' ||
        command == 'resume talking' ||
        command == 'continue' ||
        command == 'resume') {
      await _resumeNarration();
    } else if (command == 'next' ||
        command == 'next topic' ||
        command == 'skip') {
      await _nextTopic();
    } else if (command == 'previous' ||
        command == 'previous topic' ||
        command == 'back topic') {
      await _previousTopic();
    } else if (command == 'repeat' ||
        command == 'again' ||
        command == 'say again') {
      await _repeatCurrentTopic();
    } else if (command == 'help' ||
        command == 'assistance' ||
        command == 'options') {
      await _speakAssistanceOptions();
    } else if (command == 'menu' ||
        command == 'list' ||
        command == 'all topics') {
      await _speakAllTopics();
    } else if (command == 'go back' ||
        command == 'back' ||
        command == 'home' ||
        command == 'return') {
      await _navigateBack();
    } else {
      // Unknown command - provide interactive feedback
      await _audioManagerService.speakIfActive(
        'help',
        "Say 'one' through 'six' for assistance topics, 'pause' to stop, 'play' to continue, 'next' for next topic, 'previous' for previous topic, 'repeat' to hear again, 'help' for options, or 'go back' to return.",
      );
    }
  }

  Future<void> _navigateBack() async {
    await _audioManagerService.speakIfActive(
      'help',
      "Returning to your adventure hub.",
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // User control methods for pause, play, and navigation
  Future<void> _pauseNarration() async {
    await _audioManagerService.stopAllAudio();
    setState(() {
      _isPaused = true;
      _isNarrating = false;
    });
    await _audioManagerService.speakIfActive(
      'help',
      "Narration paused. Say 'play' to continue, 'next' for next topic, 'previous' for previous topic, or 'repeat' to hear again.",
    );
  }

  Future<void> _resumeNarration() async {
    setState(() {
      _isPaused = false;
      _isNarrating = true;
    });

    if (_currentTopicIndex >= 0 && _currentTopicIndex < _helpTopics.length) {
      await _speakTopicDetails(_currentTopicIndex);
    } else {
      await _speakAllTopics();
    }

    setState(() {
      _isNarrating = false;
    });
  }

  Future<void> _nextTopic() async {
    _currentTopicIndex = (_currentTopicIndex + 1) % _helpTopics.length;
    setState(() {
      _isPaused = false;
      _isNarrating = true;
    });

    final topic = _helpTopics[_currentTopicIndex];
    await _audioManagerService.speakIfActive(
      'help',
      "Next topic: ${topic['title']}. ${topic['description']}. ${topic['commands']}. Say 'pause' to stop, 'play' to continue, 'next' for next topic, 'previous' for previous topic, 'repeat' to hear again, or 'go back' to return.",
    );

    setState(() {
      _isNarrating = false;
    });
  }

  Future<void> _previousTopic() async {
    _currentTopicIndex =
        (_currentTopicIndex - 1 + _helpTopics.length) % _helpTopics.length;
    setState(() {
      _isPaused = false;
      _isNarrating = true;
    });

    final topic = _helpTopics[_currentTopicIndex];
    await _audioManagerService.speakIfActive(
      'help',
      "Previous topic: ${topic['title']}. ${topic['description']}. ${topic['commands']}. Say 'pause' to stop, 'play' to continue, 'next' for next topic, 'previous' for previous topic, 'repeat' to hear again, or 'go back' to return.",
    );

    setState(() {
      _isNarrating = false;
    });
  }

  Future<void> _repeatCurrentTopic() async {
    setState(() {
      _isPaused = false;
      _isNarrating = true;
    });

    await _speakTopicDetails(_currentTopicIndex);

    setState(() {
      _isNarrating = false;
    });
  }

  @override
  void dispose() {
    tts.stop();
    speech.stop();
    _audioControlSubscription?.cancel();
    _screenActivationSubscription?.cancel();
    _transitionSubscription?.cancel();
    _helpCommandSubscription?.cancel();
    _audioManagerService.unregisterScreen('help');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Assistance"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
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
                _speakAllTopics();
              }
            },
            tooltip: _isNarrating ? 'Stop Narration' : 'Start Narration',
          ),
          IconButton(
            icon: Icon(Icons.home),
            onPressed: () async {
              await _audioManagerService.speakIfActive(
                'help',
                "Returning to your adventure hub.",
              );
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
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
                        ? "Narration paused - Topic ${_currentTopicIndex + 1}"
                        : _isNarrating
                        ? "Providing assistance..."
                        : "Your personal guide is ready to help",
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
                          await _resumeNarration();
                        } else {
                          await _pauseNarration();
                        }
                      },
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: _isPaused ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      tooltip: _isPaused ? 'Play' : 'Pause',
                    ),
                    // Repeat button
                    IconButton(
                      onPressed: () async {
                        await _repeatCurrentTopic();
                      },
                      icon: Icon(Icons.replay, color: Colors.purple, size: 24),
                      tooltip: 'Repeat Topic',
                    ),
                    // Previous button
                    IconButton(
                      onPressed: () async {
                        await _previousTopic();
                      },
                      icon: Icon(
                        Icons.skip_previous,
                        color: Colors.blue,
                        size: 24,
                      ),
                      tooltip: 'Previous Topic',
                    ),
                    // Next button
                    IconButton(
                      onPressed: () async {
                        await _nextTopic();
                      },
                      icon: Icon(Icons.skip_next, color: Colors.blue, size: 24),
                      tooltip: 'Next Topic',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Assistance topics list with tour-style UX
          Expanded(
            child: ListView.builder(
              itemCount: _helpTopics.length,
              itemBuilder: (context, index) {
                final topic = _helpTopics[index];
                final isCurrentTopic = index == _currentTopicIndex;
                return Card(
                  color: isCurrentTopic ? Colors.blue[900] : Colors.grey[900],
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isCurrentTopic ? Colors.orange : Colors.blue,
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
                      topic['title']!,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(
                          topic['description']!,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          topic['commands']!,
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _speakTopicDetails(index),
                    trailing: Icon(Icons.help_outline, color: Colors.blue),
                  ),
                );
              },
            ),
          ),

          // Voice control tips panel
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Text(
                  "🎤 Voice Control Tips",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Say 'one' through 'six' for topics • 'pause' to stop • 'play' to continue • 'next' for next topic • 'previous' for previous topic • 'repeat' to hear again • 'help' for options • 'go back' to return",
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
