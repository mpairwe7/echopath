import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vibration/vibration.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'services/audio_manager_service.dart';
import 'services/screen_transition_manager.dart';
import 'services/voice_navigation_service.dart';
import 'services/voice_command_service.dart';
import 'audio_guide_screen.dart';

class TourDiscoveryScreen extends StatefulWidget {
  const TourDiscoveryScreen({super.key});

  @override
  State<TourDiscoveryScreen> createState() => _TourDiscoveryScreenState();
}

class _TourDiscoveryScreenState extends State<TourDiscoveryScreen> {
  late FlutterTts tts;
  late SpeechToText speech;
  late AudioManagerService _audioManagerService;
  late ScreenTransitionManager _screenTransitionManager;
  late VoiceNavigationService _voiceNavigationService;
  late VoiceCommandService _voiceCommandService;

  StreamSubscription? _audioControlSubscription;
  StreamSubscription? _screenActivationSubscription;
  StreamSubscription? _transitionSubscription;
  StreamSubscription? _voiceStatusSubscription;
  StreamSubscription? _navigationCommandSubscription;
  StreamSubscription? _discoverCommandSubscription;
  StreamSubscription? _voiceCommandSubscription;

  bool _isVoiceInitialized = false;
  bool _isListening = false;
  String _voiceStatus = 'Initializing...';
  String locationInfo = "Fetching nearby attractions...";
  bool _isLoading = true;
  bool _isAudioActive = false;
  bool _isNarrating = false;

  // Tour discovery state
  List<Map<String, dynamic>> _availableTours = [];
  String? _selectedTour;
  bool _isStartingTour = false;

  // Discover screen specific voice command state
  bool _isDiscoverVoiceEnabled = true;
  bool _isTourDiscoveryMode = false;
  bool _isPlaceExplorationMode = false;
  bool _isDetailedTourInfo = false;
  String _lastSpokenTour = '';
  int _commandCount = 0;
  int _currentTourIndex = 0; // Track current tour for next functionality
  bool _isPaused = false; // Track pause state

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
      _voiceCommandService = VoiceCommandService();

      // Initialize TTS and speech recognition
      tts = FlutterTts();
      speech = SpeechToText();

      await _initTTS();
      await _initSpeechToText();
      await _registerWithAudioManager();
      await _initializeVoiceNavigation();
      await _initializeVoiceCommands();
      await _fetchLocation();

      // Activate audio for discover screen
      await _activateDiscoverAudio();
    } catch (e) {
      print('Error initializing tour discovery screen services: $e');
      setState(() {
        _voiceStatus = 'Error initializing services';
      });
    }
  }

  Future<void> _activateDiscoverAudio() async {
    try {
      // Ensure map audio is deactivated first
      await _audioManagerService.deactivateScreenAudio('map');

      // Activate discover screen audio
      await _audioManagerService.activateScreenAudio('discover');
      setState(() {
        _isAudioActive = true;
      });

      // Start automatic narration
      await _startAutomaticNarration();
    } catch (e) {
      print('Error activating discover audio: $e');
    }
  }

  Future<void> _startAutomaticNarration() async {
    setState(() {
      _isNarrating = true;
    });

    // Tour discovery specific welcome with detailed tour instructions
    await _audioManagerService.speakIfActive(
      'discover',
      "Welcome to Tour Discovery! I'm your tour guide. Here you can explore amazing tours and start your adventures. Say 'one' through 'four' to select specific tours, 'play' to start a tour, 'next' for next tour, 'previous' for previous tour, 'find tours' to search, 'stop talking' to pause, 'resume talking' to continue, or 'repeat' to hear options again.",
    );

    // Brief pause for user to process
    await Future.delayed(Duration(seconds: 2));

    // Narrate available tours if loaded
    if (_availableTours.isNotEmpty) {
      await _speakAvailableTours();
    } else {
      await _audioManagerService.speakIfActive(
        'discover',
        "I'm searching for tours near your location. Say 'find tours' to search, 'refresh' to update your location, or 'one' through 'four' to select tours once they're loaded.",
      );
    }

    setState(() {
      _isNarrating = false;
    });
  }

  Future<void> _speakAvailableTours() async {
    String tourList = "Available tours in your area: ";
    for (int i = 0; i < _availableTours.length; i++) {
      final tour = _availableTours[i];
      tourList +=
          "${i + 1}. ${tour['name']}, ${tour['duration']}, ${tour['difficulty']}, ${tour['rating']} stars. ";
    }
    tourList +=
        "Say 'one' through 'four' to select a tour, 'play' to start the selected tour, 'next' for next tour, 'previous' for previous tour, 'find tours' to search again, or 'repeat' to hear options again.";

    await _audioManagerService.speakIfActive('discover', tourList);
  }

  Future<void> _initTTS() async {
    try {
      await tts.setLanguage("en-US");
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      // Configure TTS for better accent and tone support
      await tts.setVoice({
        "name": "en-us-x-sfg#female_1-local",
        "locale": "en-US",
      });

      // Set speech rate for better clarity across different accents
      await tts.setSpeechRate(0.45);
    } catch (e) {
      developer.log("TTS Init Error: $e", name: 'TTS');
    }
  }

  Future<void> _initSpeechToText() async {
    try {
      bool available = await speech.initialize(
        onError: (error) {
          developer.log("STT Error: ${error.errorMsg}", name: 'SpeechToText');
          // Handle permission errors gracefully
          if (error.errorMsg.contains('permission')) {
            setState(() {
              _voiceStatus = 'Microphone permission required';
            });
          }
        },
        onStatus: (status) {
          developer.log("STT Status: $status", name: 'SpeechToText');
          setState(() {
            if (status == 'listening') {
              _isListening = true;
              _voiceStatus = 'Listening...';
            } else if (status == 'notListening') {
              _isListening = false;
              _voiceStatus = 'Voice ready';
            }
          });
        },
      );
      if (available) {
        developer.log("STT Available", name: 'SpeechToText');
        setState(() {
          _isVoiceInitialized = true;
          _voiceStatus = 'Voice ready';
        });
      }
    } catch (e) {
      developer.log("STT Init Error: $e", name: 'SpeechToText');
      setState(() {
        _voiceStatus = 'Voice initialization failed';
      });
    }
  }

  Future<void> _registerWithAudioManager() async {
    _audioManagerService.registerScreen('discover', tts, speech);

    _audioControlSubscription = _audioManagerService.audioControlStream.listen((
      event,
    ) {
      print('Tour discovery screen audio control event: $event');
      if (event.startsWith('activated:discover')) {
        setState(() {
          _isAudioActive = true;
        });
      } else if (event.startsWith('deactivated:discover')) {
        setState(() {
          _isAudioActive = false;
        });
      }
    });

    _screenActivationSubscription = _audioManagerService.screenActivationStream
        .listen((screenId) {
          print('Tour discovery screen activation event: $screenId');
          if (screenId == 'discover') {
            setState(() {
              _isAudioActive = true;
            });
          } else {
            setState(() {
              _isAudioActive = false;
            });
          }
        });

    _transitionSubscription = _screenTransitionManager.transitionStream.listen((
      event,
    ) {
      print('Tour discovery screen transition event: $event');
      if (event.startsWith('transitioned:discover')) {
        setState(() {
          _isAudioActive = true;
        });
      }
    });
  }

  Future<void> _initializeVoiceNavigation() async {
    // Listen to discover-specific voice commands
    _discoverCommandSubscription = _voiceNavigationService.discoverCommandStream
        .listen((command) {
          _handleDiscoverVoiceCommand(command);
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
          print('Tour discovery screen navigation command: $command');
          _handleNavigationCommand(command);
        });

    // Listen to navigation commands for tour actions
    _voiceNavigationService.navigationCommandStream.listen((command) {
      print('Tour discovery screen tour command: $command');
      _handleTourCommand(command);
    });
  }

  Future<void> _initializeVoiceCommands() async {
    // Listen to discover-specific voice commands from the new service
    _voiceCommandSubscription = _voiceCommandService.discoverCommandStream
        .listen((command) {
          _handleVoiceCommand(command);
        });
  }

  void _handleVoiceCommand(String command) {
    print('🎤 Voice command received: $command');

    if (command.startsWith('find_tours')) {
      _findTours();
    } else if (command.startsWith('start_tour:')) {
      String tourName = command.split(':')[1];
      _startTour(tourName);
    } else if (command.startsWith('describe_tour:')) {
      String tourName = command.split(':')[1];
      _describeTour(tourName);
    } else if (command.startsWith('tell_about_place:')) {
      String placeName = command.split(':')[1];
      _tellAboutPlace(placeName);
    } else if (command.startsWith('refresh')) {
      _fetchLocation();
    } else if (command.startsWith('list_tours')) {
      _listTours();
    } else if (command.startsWith('help')) {
      _handleHelpCommand();
    } else if (command == 'one' || command == '1' || command == 'first') {
      _startTourByNumber(0);
    } else if (command == 'two' || command == '2' || command == 'second') {
      _startTourByNumber(1);
    } else if (command == 'three' || command == '3' || command == 'third') {
      _startTourByNumber(2);
    } else if (command == 'four' || command == '4' || command == 'fourth') {
      _startTourByNumber(3);
    }
  }

  void _startTourByNumber(int index) {
    if (index >= 0 && index < _availableTours.length) {
      _currentTourIndex = index;
      final tour = _availableTours[index];
      _startTour(tour['name']);
    } else {
      _audioManagerService.speakIfActive(
        'discover',
        "Tour number ${index + 1} not available. Say 'find tours' to see available options.",
      );
    }
  }

  void _handleNavigationCommand(String command) {
    if (command.startsWith('navigated:')) {
      String screen = command.split(':')[1];
      if (screen == 'discover') {
        // We're now on discover screen, activate audio
        _activateDiscoverAudio();
      }
    } else if (command == 'back') {
      _navigateBack();
    }
  }

  void _handleTourCommand(String command) {
    if (command == 'find_tours') {
      _findTours();
    } else if (command.startsWith('start_tour:')) {
      String tourName = command.split(':')[1];
      _startTour(tourName);
    } else if (command.startsWith('describe_tour:')) {
      String tourName = command.split(':')[1];
      _describeTour(tourName);
    } else if (command.startsWith('tell_about:')) {
      String placeName = command.split(':')[1];
      _tellAboutPlace(placeName);
    } else if (command == 'list_tours') {
      _listTours();
    } else if (command == 'tour_details') {
      _showTourDetails();
    }
  }

  Future<void> _navigateBack() async {
    // Deactivate discover audio before navigating
    await _audioManagerService.deactivateScreenAudio('discover');
    setState(() {
      _isAudioActive = false;
    });

    await _audioManagerService.speakIfActive(
      'discover',
      "Going back to previous screen.",
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // User control methods for next/previous tour navigation
  Future<void> _nextTour() async {
    if (_availableTours.isNotEmpty) {
      _currentTourIndex = (_currentTourIndex + 1) % _availableTours.length;
      final tour = _availableTours[_currentTourIndex];

      await _audioManagerService.speakIfActive(
        'discover',
        "Next tour: ${tour['name']}. ${tour['duration']}, ${tour['difficulty']}, ${tour['rating']} stars. Say 'start tour' to begin, 'next' for next tour, 'previous' for previous tour, or 'go back' to return.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'discover',
        "No tours available. Say 'find tours' to search for tours near your location.",
      );
    }
  }

  Future<void> _previousTour() async {
    if (_availableTours.isNotEmpty) {
      _currentTourIndex =
          (_currentTourIndex - 1 + _availableTours.length) %
          _availableTours.length;
      final tour = _availableTours[_currentTourIndex];

      await _audioManagerService.speakIfActive(
        'discover',
        "Previous tour: ${tour['name']}. ${tour['duration']}, ${tour['difficulty']}, ${tour['rating']} stars. Say 'start tour' to begin, 'next' for next tour, 'previous' for previous tour, or 'go back' to return.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'discover',
        "No tours available. Say 'find tours' to search for tours near your location.",
      );
    }
  }

  // Handle discover-specific voice commands
  Future<void> _handleDiscoverVoiceCommand(String command) async {
    print('🎤 Discover voice command received: $command');

    // Limit command frequency to prevent spam
    if (_commandCount > 10) {
      _commandCount = 0;
      return;
    }
    _commandCount++;

    if (command.startsWith('find_tours')) {
      await _handleFindToursCommand();
    } else if (command.startsWith('start_tour:')) {
      String tourName = command.split(':').last;
      await _handleStartTourCommand(tourName);
    } else if (command.startsWith('describe_tour:')) {
      String tourName = command.split(':').last;
      await _handleDescribeTourCommand(tourName);
    } else if (command.startsWith('tell_about_place:')) {
      String placeName = command.split(':').last;
      await _handleTellAboutPlaceCommand(placeName);
    } else if (command.startsWith('refresh')) {
      await _handleRefreshCommand();
    } else if (command.startsWith('tour_discovery_mode')) {
      await _handleTourDiscoveryModeCommand();
    } else if (command.startsWith('place_exploration_mode')) {
      await _handlePlaceExplorationModeCommand();
    } else if (command.startsWith('detailed_info')) {
      await _handleDetailedInfoCommand();
    } else if (command.startsWith('quick_info')) {
      await _handleQuickInfoCommand();
    } else if (command == 'one' || command == '1' || command == 'first') {
      _startTourByNumber(0);
    } else if (command == 'two' || command == '2' || command == 'second') {
      _startTourByNumber(1);
    } else if (command == 'three' || command == '3' || command == 'third') {
      _startTourByNumber(2);
    } else if (command == 'four' || command == '4' || command == 'fourth') {
      _startTourByNumber(3);
    } else if (command == 'next' || command == 'next tour') {
      await _nextTour();
    } else if (command == 'previous' || command == 'previous tour') {
      await _previousTour();
    } else if (command == 'repeat' || command == 'read all') {
      await _speakAvailableTours();
    } else if (command == 'stop talking' || command == 'pause') {
      await _audioManagerService.stopAllAudio();
    } else if (command == 'resume talking' || command == 'continue') {
      await _speakAvailableTours();
    } else if (command == 'go back' || command == 'back') {
      await _navigateBack();
    } else if (command.startsWith('help')) {
      await _handleHelpCommand();
    } else {
      // Unknown command - provide tour discovery specific feedback
      await _audioManagerService.speakIfActive(
        'discover',
        "In tour discovery, say 'one' through 'four' to select tours, 'play' to start a tour, 'next' for next tour, 'previous' for previous tour, 'find tours' to search, 'repeat' to hear options, or 'go back' to return.",
      );
    }
  }

  // Discover command handlers
  Future<void> _handleFindToursCommand() async {
    await _audioManagerService.speakIfActive(
      'discover',
      "Searching for available tours near your location. Let me find the best tours and attractions for you to explore.",
    );
    await _fetchLocation(); // Refresh tours
  }

  Future<void> _handleStartTourCommand(String tourName) async {
    await _audioManagerService.speakIfActive(
      'discover',
      "Starting tour: $tourName. I'll guide you through this amazing experience.",
    );
    await _startTour(tourName);
  }

  Future<void> _handleDescribeTourCommand(String tourName) async {
    await _audioManagerService.speakIfActive(
      'discover',
      "I'll provide detailed information about the $tourName tour.",
    );
    await _describeTour(tourName);
  }

  Future<void> _handleTellAboutPlaceCommand(String placeName) async {
    await _audioManagerService.speakIfActive(
      'discover',
      "I'll tell you about $placeName and what makes it special.",
    );
    await _tellAboutPlace(placeName);
  }

  Future<void> _handleRefreshCommand() async {
    await _audioManagerService.speakIfActive(
      'discover',
      "Refreshing your location and searching for new tours and attractions nearby.",
    );
    await _fetchLocation();
  }

  Future<void> _handleTourDiscoveryModeCommand() async {
    if (mounted) {
      setState(() {
        _isTourDiscoveryMode = !_isTourDiscoveryMode;
        _isPlaceExplorationMode = false;
      });
    }

    String status = _isTourDiscoveryMode ? "activated" : "deactivated";
    await _audioManagerService.speakIfActive(
      'discover',
      "Tour discovery mode $status. I'll help you find and explore the best tours available in your area.",
    );
  }

  Future<void> _handlePlaceExplorationModeCommand() async {
    if (mounted) {
      setState(() {
        _isPlaceExplorationMode = !_isPlaceExplorationMode;
        _isTourDiscoveryMode = false;
      });
    }

    String status = _isPlaceExplorationMode ? "activated" : "deactivated";
    await _audioManagerService.speakIfActive(
      'discover',
      "Place exploration mode $status. I'll provide detailed information about places and attractions in your area.",
    );
  }

  Future<void> _handleDetailedInfoCommand() async {
    if (mounted) {
      setState(() {
        _isDetailedTourInfo = true;
      });
    }

    await _audioManagerService.speakIfActive(
      'discover',
      "Detailed information mode enabled. I'll provide comprehensive details about tours and places.",
    );
  }

  Future<void> _handleQuickInfoCommand() async {
    if (mounted) {
      setState(() {
        _isDetailedTourInfo = false;
      });
    }

    await _audioManagerService.speakIfActive(
      'discover',
      "Quick information mode enabled. I'll provide brief, essential information about tours and places.",
    );
  }

  Future<void> _handleHelpCommand() async {
    await _audioManagerService.speakIfActive(
      'discover',
      "Tour Discovery commands: 'one' through 'four' for specific tours, 'find tours' to search, 'repeat' to hear again, 'stop talking' to pause, 'resume talking' to continue, 'go back' to return, or say tour name to start.",
    );
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _isLoading = true;
    });

    // Check for location service permission and status
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        locationInfo = "Location services are disabled. Please enable them.";
        _isLoading = false;
      });
      await _audioManagerService.speakIfActive('discover', locationInfo);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          locationInfo = "Location permissions are denied. Please grant them.";
          _isLoading = false;
        });
        await _audioManagerService.speakIfActive('discover', locationInfo);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        locationInfo =
            "Location permissions are permanently denied. We cannot request permissions.";
        _isLoading = false;
      });
      await _audioManagerService.speakIfActive('discover', locationInfo);
      return;
    }

    try {
      await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Simulate finding nearby tours
      await _loadAvailableTours();

      setState(() {
        locationInfo =
            "Found ${_availableTours.length} tours near your location. Say 'one' through 'four' for specific tours or 'find tours' to hear the list.";
        _isLoading = false;
      });

      await _audioManagerService.speakIfActive('discover', locationInfo);
    } catch (e) {
      setState(() {
        locationInfo = "Error getting your location. Please try again.";
        _isLoading = false;
      });
      await _audioManagerService.speakIfActive('discover', locationInfo);
    }
  }

  Future<void> _loadAvailableTours() async {
    // Simulate loading tours from a database
    _availableTours = [
      {
        'name': 'Murchison Falls Adventure',
        'duration': '2 hours',
        'distance': '15 km',
        'description':
            'Explore the magnificent Murchison Falls, one of Uganda\'s most spectacular natural wonders.',
        'difficulty': 'Easy',
        'rating': 4.8,
      },
      {
        'name': 'Kasubi Tombs Heritage',
        'duration': '1.5 hours',
        'distance': '8 km',
        'description':
            'Discover the royal tombs of the Buganda kingdom, a UNESCO World Heritage site.',
        'difficulty': 'Easy',
        'rating': 4.6,
      },
      {
        'name': 'Bwindi Forest Trek',
        'duration': '3 hours',
        'distance': '25 km',
        'description':
            'Experience the mystical Bwindi forest, home to endangered mountain gorillas.',
        'difficulty': 'Moderate',
        'rating': 4.9,
      },
      {
        'name': 'Lake Victoria Explorer',
        'duration': '2.5 hours',
        'distance': '12 km',
        'description':
            'Journey around Africa\'s largest lake, exploring its islands and fishing communities.',
        'difficulty': 'Easy',
        'rating': 4.5,
      },
    ];
  }

  Future<void> _findTours() async {
    if (_availableTours.isEmpty) {
      await _audioManagerService.speakIfActive(
        'discover',
        "No tours found. Try 'refresh' or check location settings.",
      );
      return;
    }

    await _speakAvailableTours();
  }

  Future<void> _startTour(String tourName) async {
    final tour = _availableTours.firstWhere(
      (t) => t['name'].toLowerCase().contains(tourName.toLowerCase()),
      orElse: () => _availableTours[0],
    );

    setState(() {
      _selectedTour = tour['name'];
      _isStartingTour = true;
    });

    await _audioManagerService.speakIfActive(
      'discover',
      "Starting ${tour['name']}. ${tour['description']} Duration: ${tour['duration']}. Difficulty: ${tour['difficulty']}. Get ready for your adventure!",
    );

    // Simulate tour preparation
    await Future.delayed(Duration(seconds: 2));

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AudioGuideScreen()),
      );
    }

    setState(() {
      _isStartingTour = false;
    });
  }

  // Enhanced tour narration methods
  Future<void> _describeTour(String tourName) async {
    final tour = _availableTours.firstWhere(
      (t) => t['name'].toLowerCase().contains(tourName.toLowerCase()),
      orElse: () => _availableTours[0],
    );

    String description = """
    ${tour['name']}: ${tour['difficulty']} difficulty, ${tour['duration']}, ${tour['distance']}, ${tour['rating']} stars. 
    ${tour['description']} 
    Perfect for ${tour['difficulty'] == 'Easy'
        ? 'beginners and families'
        : tour['difficulty'] == 'Moderate'
        ? 'adventure seekers'
        : 'experienced travelers'}.
    Say 'start tour ${tour['name']}' to begin.
    """;

    await _audioManagerService.speakIfActive('discover', description);
  }

  Future<void> _tellAboutPlace(String placeName) async {
    // Enhanced place narration with detailed information
    Map<String, Map<String, String>> placeDetails = {
      'murchison': {
        'name': 'Murchison Falls',
        'description':
            'Murchison Falls is one of Uganda\'s most spectacular natural wonders. The Nile River forces its way through a narrow gorge, creating a powerful waterfall that plunges 43 meters. The area is rich in wildlife including elephants, lions, giraffes, and over 450 bird species. The falls are named after Sir Roderick Murchison, a Scottish geologist.',
        'highlights':
            'Wildlife viewing, boat safaris, hiking trails, and stunning photography opportunities.',
        'best_time':
            'The best time to visit is during the dry season from December to February and June to September.',
        'tips':
            'Bring binoculars for wildlife viewing, wear comfortable walking shoes, and don\'t forget your camera.',
      },
      'kasubi': {
        'name': 'Kasubi Tombs',
        'description':
            'The Kasubi Tombs are the royal burial grounds of the Buganda kingdom, a UNESCO World Heritage site. This sacred site contains the tombs of four Kabakas (kings) and is an important cultural and spiritual center for the Baganda people. The main building is a masterpiece of traditional architecture.',
        'highlights':
            'Traditional architecture, cultural significance, guided tours, and historical insights.',
        'best_time':
            'Visit during weekdays for fewer crowds and better guided tour availability.',
        'tips':
            'Dress respectfully, remove shoes before entering, and photography may be restricted in certain areas.',
      },
      'bwindi': {
        'name': 'Bwindi Forest',
        'description':
            'Bwindi Impenetrable Forest is a UNESCO World Heritage site and home to endangered mountain gorillas. This ancient forest is over 25,000 years old and contains over 400 plant species. The forest is also home to chimpanzees, various monkey species, and over 350 bird species.',
        'highlights':
            'Gorilla trekking, bird watching, forest walks, and cultural village visits.',
        'best_time':
            'The best time for gorilla trekking is during the dry seasons from June to August and December to February.',
        'tips':
            'Gorilla trekking requires a permit, wear appropriate hiking gear, and be prepared for challenging terrain.',
      },
      'lake victoria': {
        'name': 'Lake Victoria',
        'description':
            'Lake Victoria is Africa\'s largest lake and the world\'s largest tropical lake. It spans three countries and is a vital source of the Nile River. The lake is home to diverse fish species and supports many fishing communities. The islands offer unique cultural experiences and beautiful scenery.',
        'highlights':
            'Island visits, fishing trips, boat tours, cultural experiences, and sunset views.',
        'best_time':
            'Visit year-round, but the dry season offers the best weather for water activities.',
        'tips':
            'Bring sunscreen, wear a hat, and consider taking motion sickness medication for boat trips.',
      },
    };

    // Find matching place
    String? matchedPlace;
    for (String key in placeDetails.keys) {
      if (placeName.toLowerCase().contains(key)) {
        matchedPlace = key;
        break;
      }
    }

    if (matchedPlace != null) {
      final place = placeDetails[matchedPlace]!;
      String narration = """
        ${place['name']}. ${place['description']} 
        Highlights include: ${place['highlights']} 
        ${place['best_time']} 
        Travel tips: ${place['tips']}
      """;
      await _audioManagerService.speakIfActive('discover', narration);
    } else {
      await _audioManagerService.speakIfActive(
        'discover',
        "I don't have specific information about $placeName, but I can tell you about Murchison Falls, Kasubi Tombs, Bwindi Forest, or Lake Victoria. Just ask me to tell you about any of these places.",
      );
    }
  }

  Future<void> _listTours() async {
    if (_availableTours.isEmpty) {
      await _audioManagerService.speakIfActive(
        'discover',
        "No tours available. Try 'refresh' or check back later.",
      );
      return;
    }

    await _speakAvailableTours();
  }

  Future<void> _showTourDetails() async {
    if (_selectedTour == null) {
      await _audioManagerService.speakIfActive(
        'discover',
        "No tour selected. Say 'find tours' to see options, then 'start tour' plus name.",
      );
      return;
    }

    final tour = _availableTours.firstWhere(
      (t) => t['name'] == _selectedTour,
      orElse: () => _availableTours[0],
    );

    String details = """
      Selected: ${tour['name']}
      Duration: ${tour['duration']}
      Distance: ${tour['distance']}
      Difficulty: ${tour['difficulty']}
      Rating: ${tour['rating']} stars
      Description: ${tour['description']}
      Say 'start tour ${tour['name']}' to begin.
    """;

    await _audioManagerService.speakIfActive('discover', details);
  }

  @override
  void dispose() {
    tts.stop();
    speech.stop();
    _audioControlSubscription?.cancel();
    _screenActivationSubscription?.cancel();
    _transitionSubscription?.cancel();
    _voiceStatusSubscription?.cancel();
    _navigationCommandSubscription?.cancel();
    _discoverCommandSubscription?.cancel();
    _voiceCommandSubscription?.cancel();
    _audioManagerService.unregisterScreen('discover');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Tour Discovery"),
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
                _speakAvailableTours();
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
                    _isNarrating
                        ? "Narrating tours..."
                        : _availableTours.isNotEmpty
                        ? "Tour ${_currentTourIndex + 1} of ${_availableTours.length}"
                        : "Tap tours or use voice commands",
                    style: TextStyle(
                      color: _isNarrating ? Colors.green : Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
                Row(
                  children: [
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

          // Main content
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Finding tours near you...",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                    : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationInfo,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(height: 20),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.search),
                                  label: Text("Find Tours"),
                                  onPressed: _findTours,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.refresh),
                                  label: Text("Refresh"),
                                  onPressed: _fetchLocation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          // Available tours list
                          Text(
                            "Available Tours",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          // Tour list
                          Expanded(
                            child:
                                _availableTours.isEmpty
                                    ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.search,
                                            size: 64,
                                            color: Colors.grey[600],
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No tours found',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Tap "Find Tours" to search',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: _availableTours.length,
                                      itemBuilder: (context, index) {
                                        final tour = _availableTours[index];
                                        return Card(
                                          color: Colors.grey[900],
                                          margin: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 4,
                                          ),
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
                                              tour['name'],
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(height: 4),
                                                Text(
                                                  '${tour['duration']} • ${tour['difficulty']} • ${tour['rating']}★',
                                                  style: TextStyle(
                                                    color: Colors.grey[300],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  tour['description'],
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
                                                      : 'four'}' or 'start tour ${tour['name']}' to begin",
                                                  style: TextStyle(
                                                    color: Colors.blue[300],
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: ElevatedButton(
                                              onPressed:
                                                  () =>
                                                      _startTour(tour['name']),
                                              child: Text('Start'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                            onTap: () => _showTourDetails(),
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
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
                  "Say 'one' through 'four' for tours • 'find tours' to search • 'next' for next tour • 'previous' for previous tour • 'stop talking' to pause • 'resume talking' to continue • 'go back' to return",
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
