import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';

import "tour_discovery_screen.dart";
import "downloads_screen.dart";
import "help_and_support_screen.dart";
import "screens/map_screen.dart";
import "services/voice_navigation_service.dart";
import "services/audio_manager_service.dart";
import "services/screen_transition_manager.dart";

class AppScaffold extends StatefulWidget {
  final int selectedIndex;
  final Widget child;
  final Function(int)? onTabChanged;
  const AppScaffold({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.onTabChanged,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  late FlutterTts tts;
  final VoiceNavigationService _voiceNavigationService =
      VoiceNavigationService();
  final AudioManagerService _audioManagerService = AudioManagerService();
  final ScreenTransitionManager _screenTransitionManager =
      ScreenTransitionManager();
  StreamSubscription<String>? _screenNavigationSubscription;
  StreamSubscription<String>? _audioControlSubscription;
  StreamSubscription<String>? _screenActivationSubscription;
  StreamSubscription<String>? _transitionSubscription;

  @override
  void initState() {
    super.initState();
    tts = FlutterTts();
    _initializeVoiceNavigation();
  }

  Future<void> _initializeVoiceNavigation() async {
    // Listen to screen navigation commands
    _screenNavigationSubscription = _voiceNavigationService
        .screenNavigationStream
        .listen((screen) {
          _handleScreenNavigation(screen);
        });

    // Listen to audio control events
    _audioControlSubscription = _audioManagerService.audioControlStream.listen((
      event,
    ) {
      print('AppScaffold audio control event: $event');
    });

    // Listen to screen activation events
    _screenActivationSubscription = _audioManagerService.screenActivationStream
        .listen((screenId) {
          print('Screen activated: $screenId');
        });

    // Listen to transition events
    _transitionSubscription = _screenTransitionManager.transitionStream.listen((
      event,
    ) {
      print('Transition event: $event');
    });
  }

  void _handleScreenNavigation(String screen) {
    print('Home screen handling navigation to: $screen');
    // Use screen transition manager for smooth navigation
    _screenTransitionManager.handleVoiceNavigation(screen).then((_) {
      // Update UI after transition
      switch (screen) {
        case 'home':
          if (widget.onTabChanged != null) {
            widget.onTabChanged!(0);
          }
          break;
        case 'map':
          if (widget.onTabChanged != null) {
            widget.onTabChanged!(1);
          }
          break;
        case 'discover':
          if (widget.onTabChanged != null) {
            widget.onTabChanged!(2);
          }
          break;
        case 'downloads':
          if (widget.onTabChanged != null) {
            widget.onTabChanged!(3);
          }
          break;
        case 'help':
          print('Setting tab to help (index 4)');
          if (widget.onTabChanged != null) {
            widget.onTabChanged!(4);
          }
          break;
      }
    });
  }

  Future<void> _speakTabInfo(int index) async {
    String message;
    switch (index) {
      case 0:
        message =
            "Home - Navigation hub. Say 'one' for map, 'two' for tours, 'three' for downloads, 'four' for help.";
        break;
      case 1:
        message =
            "Map - Interactive exploration. Say 'one' to describe surroundings, 'two' to discover places, 'three' for facilities.";
        break;
      case 2:
        message =
            "Discover - Tour exploration. Say 'one' through 'four' to select tours, 'play' to start, 'next' for next tour.";
        break;
      case 3:
        message =
            "Downloads - Offline content. Say 'one' through 'four' to select tours, 'play' to start, 'pause' to pause.";
        break;
      case 4:
        message =
            "Assistance - Help and support. Say 'one' through 'six' for topics, 'pause' to pause, 'play' to resume.";
        break;
      default:
        message = "Tab selected.";
    }
    await tts.speak(message);
  }

  void _onItemTapped(int index) {
    _speakTabInfo(index);
    if (widget.onTabChanged != null) {
      widget.onTabChanged!(index);
    }
  }

  @override
  void dispose() {
    _screenNavigationSubscription?.cancel();
    _audioControlSubscription?.cancel();
    _screenActivationSubscription?.cancel();
    _transitionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        iconSize: 24,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.tour), label: 'Discover'),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'My Content',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: 'Assistance',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  late FlutterTts tts;
  late stt.SpeechToText speech;
  final VoiceNavigationService _voiceNavigationService =
      VoiceNavigationService();
  final AudioManagerService _audioManagerService = AudioManagerService();
  final ScreenTransitionManager _screenTransitionManager =
      ScreenTransitionManager();

  StreamSubscription<String>? _voiceStatusSubscription;
  StreamSubscription<String>? _audioStatusSubscription;
  StreamSubscription<String>? _transitionStatusSubscription;
  StreamSubscription<String>? _navigationCommandSubscription;
  StreamSubscription<String>? _homeCommandSubscription;

  bool _isVoiceInitialized = false;
  bool _isListening = false;
  String _voiceStatus = 'Initializing...';

  // Home screen specific voice command state
  bool _isHomeVoiceEnabled = true;
  bool _isWelcomeMessageEnabled = true;
  bool _isQuickAccessEnabled = true;
  String _lastSpokenFeature = '';
  int _commandCount = 0;
  bool _isNarrating = false; // For tour-style narration control

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize TTS and speech recognition
      tts = FlutterTts();
      speech = stt.SpeechToText();

      // Register with audio manager
      _audioManagerService.registerScreen('home', tts, speech);

      // Initialize voice navigation
      _isVoiceInitialized = await _voiceNavigationService.initialize();
      if (_isVoiceInitialized) {
        await _voiceNavigationService.startContinuousListening();
        setState(() {
          _voiceStatus = 'Voice navigation ready';
          _isListening = true;
        });
      }

      // Listen to voice status updates
      _voiceStatusSubscription = _voiceNavigationService.voiceStatusStream
          .listen((status) {
            setState(() {
              _voiceStatus = status;
              if (status.startsWith('listening_started')) {
                _isListening = true;
              } else if (status.startsWith('listening_stopped')) {
                _isListening = false;
              }
            });
          });

      // Listen to audio status updates
      _audioStatusSubscription = _audioManagerService.audioStatusStream.listen((
        status,
      ) {
        print('Home screen audio status: $status');
      });

      // Listen to transition status updates
      _transitionStatusSubscription = _screenTransitionManager
          .transitionStatusStream
          .listen((status) {
            print('Home screen transition status: $status');
          });

      // Listen to navigation commands
      _navigationCommandSubscription = _voiceNavigationService
          .navigationCommandStream
          .listen((command) {
            print('Home screen navigation command: $command');
          });

      // Listen to home-specific voice commands
      _homeCommandSubscription = _voiceNavigationService.homeCommandStream
          .listen((command) {
            _handleHomeVoiceCommand(command);
          });

      // Activate home screen audio
      await _audioManagerService.activateScreenAudio('home');
      await _screenTransitionManager.navigateToScreen('home');

      // Start tour-style welcome narration
      await _startTourStyleWelcome();
    } catch (e) {
      print('Error initializing home screen services: $e');
      setState(() {
        _voiceStatus = 'Error initializing voice navigation';
      });
    }
  }

  // Home-specific welcome narration - focused on navigation only
  Future<void> _startTourStyleWelcome() async {
    setState(() {
      _isNarrating = true;
    });

    // Home-focused welcome with navigation options only
    await _audioManagerService.speakIfActive(
      'home',
      "Welcome to EchoPath! Your navigation hub. Say 'one' for map exploration, 'two' for tour discovery, 'three' for offline content, or 'four' for assistance. Each screen has its own specific instructions.",
    );

    setState(() {
      _isNarrating = false;
    });
  }

  @override
  void dispose() {
    _voiceStatusSubscription?.cancel();
    _audioStatusSubscription?.cancel();
    _transitionStatusSubscription?.cancel();
    _navigationCommandSubscription?.cancel();
    _audioManagerService.unregisterScreen('home');
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Use screen transition manager for smooth navigation
    _screenTransitionManager.handleTabChange(index);
  }

  // Streamlined navigation method for seamless transitions
  Future<void> _navigateToScreen(String screen) async {
    try {
      // Provide home-specific navigation feedback
      String feedback = "";
      switch (screen) {
        case 'map':
          feedback = "From home, navigating to map exploration";
          setState(() => _selectedIndex = 1);
          break;
        case 'discover':
          feedback = "From home, navigating to tour discovery";
          setState(() => _selectedIndex = 2);
          break;
        case 'downloads':
          feedback = "From home, navigating to offline content";
          setState(() => _selectedIndex = 3);
          break;
        case 'help':
          feedback = "From home, navigating to assistance";
          setState(() => _selectedIndex = 4);
          break;
        case 'home':
          feedback = "Already on home screen";
          setState(() => _selectedIndex = 0);
          break;
      }

      // Speak feedback and navigate
      await _audioManagerService.speakIfActive('home', feedback);
      await _screenTransitionManager.handleVoiceNavigation(screen);
    } catch (e) {
      print('Error navigating to screen $screen: $e');
      await _audioManagerService.speakIfActive(
        'home',
        "Navigation error. Please try again.",
      );
    }
  }

  // Streamlined voice command handler for seamless navigation
  Future<void> _handleHomeVoiceCommand(String command) async {
    print('🎤 Home voice command received: $command');

    // Limit command frequency to prevent spam
    if (_commandCount > 10) {
      _commandCount = 0;
      return;
    }
    _commandCount++;

    // SIMPLE NUMBER-BASED NAVIGATION: Quick and seamless
    if (command == 'one' || command == '1' || command == 'map') {
      await _navigateToScreen('map');
      return;
    } else if (command == 'two' || command == '2' || command == 'discover') {
      await _navigateToScreen('discover');
      return;
    } else if (command == 'three' || command == '3' || command == 'downloads') {
      await _navigateToScreen('downloads');
      return;
    } else if (command == 'four' || command == '4' || command == 'help') {
      await _navigateToScreen('help');
      return;
    } else if (command == 'repeat' || command == 'welcome') {
      await _startTourStyleWelcome();
      return;
    } else if (command == 'stop talking' || command == 'pause') {
      await _audioManagerService.stopAllAudio();
      return;
    } else if (command == 'resume talking' || command == 'continue') {
      await _startTourStyleWelcome();
      return;
    } else {
      // Unknown command - provide home-specific feedback
      await _audioManagerService.speakIfActive(
        'home',
        "From home, say 'one' for map, 'two' for tours, 'three' for downloads, 'four' for help, or 'repeat' to hear navigation options.",
      );
    }
  }

  // Streamlined command handlers for seamless navigation
  Future<void> _handleWelcomeCommand() async {
    await _audioManagerService.speakIfActive(
      'home',
      "EchoPath. Say 'one' for map, 'two' for tours, 'three' for downloads, 'four' for help.",
    );
  }

  Future<void> _handleQuickAccessCommand() async {
    await _audioManagerService.speakIfActive(
      'home',
      "Quick navigation: 'one' for map, 'two' for tours, 'three' for downloads, 'four' for help.",
    );
  }

  Future<void> _handleVoiceSettingsCommand() async {
    await _audioManagerService.speakIfActive(
      'home',
      "Voice control: 'stop talking' to pause, 'resume talking' to continue.",
    );
  }

  Future<void> _handleStatusCommand() async {
    String status =
        "Voice ${_isListening ? 'on' : 'off'}, Navigation ready. Say 'one' through 'four' to navigate.";
    await _audioManagerService.speakIfActive('home', status);
  }

  Future<void> _handleHelpCommand() async {
    await _audioManagerService.speakIfActive(
      'home',
      "Navigation: 'one' for map, 'two' for tours, 'three' for downloads, 'four' for help. 'repeat' to hear options.",
    );
  }

  // Tour-style adventure card builder
  Widget _buildAdventureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      selectedIndex: _selectedIndex,
      onTabChanged: _onTabChanged,
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          // Home tab content - Tour-style experience for blind users
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Status indicator and control panel
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isNarrating
                                ? "🎤 Narrating..."
                                : "🎧 Ready to explore",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isNarrating ? Colors.blue : Colors.green,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (_isNarrating) {
                                await _audioManagerService.stopAllAudio();
                                setState(() => _isNarrating = false);
                              } else {
                                await _startTourStyleWelcome();
                              }
                            },
                            icon: Icon(
                              _isNarrating ? Icons.pause : Icons.play_arrow,
                              color: _isNarrating ? Colors.blue : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Home navigation ready",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Main app title with tour-style branding
                Column(
                  children: [
                    const Text(
                      "EchoPath",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Your Personal Tour Companion",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Adventure cards - Tour-style navigation
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      // Explore Adventure Card
                      _buildAdventureCard(
                        title: "Explore",
                        subtitle: "Discover the world around you",
                        icon: Icons.explore,
                        color: Colors.green,
                        onTap: () async => await _navigateToScreen('map'),
                      ),
                      // Discover Adventure Card
                      _buildAdventureCard(
                        title: "Discover",
                        subtitle: "Find amazing tours",
                        icon: Icons.tour,
                        color: Colors.orange,
                        onTap: () async => await _navigateToScreen('discover'),
                      ),
                      // My Content Adventure Card
                      _buildAdventureCard(
                        title: "My Content",
                        subtitle: "Your saved adventures",
                        icon: Icons.library_books,
                        color: Colors.purple,
                        onTap: () async => await _navigateToScreen('downloads'),
                      ),
                      // Assistance Adventure Card
                      _buildAdventureCard(
                        title: "Assistance",
                        subtitle: "Get help and support",
                        icon: Icons.support_agent,
                        color: Colors.red,
                        onTap: () async => await _navigateToScreen('help'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Voice control tips panel
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "🎤 Voice Control Tips",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Home navigation: 'one' for map • 'two' for tours • 'three' for downloads • 'four' for help • 'repeat' for options • 'stop talking' to pause • 'resume talking' to continue",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Map, Discover, Downloads, Help & Support tabs
          const MapScreen(),
          const TourDiscoveryScreen(),
          const DownloadsScreen(),
          const HelpAndSupportScreen(),
        ],
      ),
    );
  }
}
