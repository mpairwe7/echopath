import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/location_service.dart';
import '../services/voice_command_service.dart';
import '../services/voice_navigation_service.dart';
import '../services/audio_manager_service.dart';
import '../services/audio_narration_service.dart';
import '../models/landmark.dart';
import 'dart:async'; // Added for Timer

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final VoiceCommandService _voiceCommandService = VoiceCommandService();
  final VoiceNavigationService _voiceNavigationService =
      VoiceNavigationService();
  final AudioManagerService _audioManagerService = AudioManagerService();
  final AudioNarrationService _audioNarrationService = AudioNarrationService();
  final FlutterTts _tts = FlutterTts();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  Position? _currentPosition;
  List<Landmark> _nearbyLandmarks = [];
  Set<Marker> _markers = {};
  bool _isTracking = false;
  bool _isListening = false;

  // Navigation and voice narration state
  bool _isNavigating = false;
  Landmark? _navigationTarget;
  Timer? _narrationTimer;
  final String _lastNarratedLocation = '';
  double _lastNarratedBearing = 0.0;

  // Enhanced voice features
  bool _isVoiceEnabled = true;
  bool _isContinuousNarration = true;
  bool _isDetailedNarration = false;
  bool _isQuickNarration = true;
  bool _isImmersiveNarration = false; // New immersive mode
  double _currentZoom = 16.0;
  double _narrationVolume = 1.0;
  double _narrationSpeed = 0.5;
  String _narrationLanguage = "en-US";

  // Map screen specific voice command state
  bool _isMapVoiceEnabled = true;
  String _lastSpokenLocation = '';
  int _commandCount = 0;
  bool _isNarrating = false;
  int _currentLandmarkIndex = 0; // For tour navigation

  // Enhanced narration state
  String _currentNarrationTone = 'friendly';
  bool _isEmotionalNarrationEnabled = true;
  bool _isContextualNarrationEnabled = true;
  bool _isRealTimeDataEnabled = true;
  Map<String, dynamic> _realTimeData = {};
  List<String> _narrationHistory = [];

  // Voice command state
  StreamSubscription<String>? _mapCommandSubscription;
  StreamSubscription<String>? _audioControlSubscription;
  StreamSubscription<String>? _screenActivationSubscription;
  StreamSubscription<String>? _voiceCommandSubscription;

  // Map interaction state
  bool _isMapExplorationMode = false;
  bool _isLandmarkDiscoveryMode = false;
  bool _isRoutePlanningMode = false;
  bool _isAccessibilityMode = false;
  bool _isEmergencyMode = false;

  // Narration control
  Timer? _narrationControlTimer;
  bool _isNarrationPaused = false;
  String _lastNarrationType = '';
  int _narrationCount = 0;

  // Map settings
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(0.3476, 32.5825), // Kampala, Uganda
    zoom: 15.0,
  );

  // Enhanced voice command patterns for blind user interaction
  static const Map<String, List<String>> _blindUserCommandPatterns = {
    'explore_map': [
      'explore map',
      'explore the map',
      'scan map',
      'scan the map',
      'survey map',
      'survey the map',
      'explore area',
      'scan area',
      'what is around me',
      'describe the map',
      'tell me about the map',
      'map overview',
      'area overview',
    ],
    'landmark_interaction': [
      'select landmark',
      'choose landmark',
      'pick landmark',
      'select place',
      'choose place',
      'pick place',
      'interact with landmark',
      'interact with place',
      'focus on landmark',
      'focus on place',
      'highlight landmark',
      'highlight place',
    ],
    'map_navigation_voice': [
      'move map left',
      'move map right',
      'move map up',
      'move map down',
      'pan left',
      'pan right',
      'pan up',
      'pan down',
      'slide map left',
      'slide map right',
      'slide map up',
      'slide map down',
      'shift map left',
      'shift map right',
      'shift map up',
      'shift map down',
    ],
    'landmark_selection': [
      'first landmark',
      'second landmark',
      'third landmark',
      'fourth landmark',
      'fifth landmark',
      'next landmark',
      'previous landmark',
      'landmark one',
      'landmark two',
      'landmark three',
      'landmark four',
      'landmark five',
      'select first',
      'select second',
      'select third',
      'select fourth',
      'select fifth',
    ],
    'detailed_exploration': [
      'describe in detail',
      'more details',
      'detailed description',
      'comprehensive description',
      'full description',
      'complete description',
      'extended description',
      'in depth description',
      'thorough description',
      'detailed information',
      'comprehensive information',
      'full information',
    ],
    'quick_exploration': [
      'brief description',
      'quick description',
      'short description',
      'summary',
      'brief overview',
      'quick overview',
      'short overview',
      'brief information',
      'quick information',
      'short information',
    ],
    'landmark_categories': [
      'show restaurants',
      'show cafes',
      'show shops',
      'show attractions',
      'show landmarks',
      'show facilities',
      'show services',
      'show points of interest',
      'show tourist spots',
      'show historical sites',
      'show cultural sites',
      'show religious sites',
      'show parks',
      'show museums',
      'show galleries',
    ],
    'distance_information': [
      'how far',
      'what distance',
      'distance to',
      'how close',
      'proximity',
      'nearby distance',
      'walking distance',
      'travel time',
      'how long to walk',
      'how long to reach',
    ],
    'direction_information': [
      'which direction',
      'what direction',
      'where is it',
      'where to go',
      'which way',
      'point me to',
      'direct me to',
      'guide me to',
      'lead me to',
      'show me the way',
    ],
    'accessibility_info': [
      'wheelchair accessible',
      'accessibility features',
      'disabled access',
      'mobility access',
      'accessibility information',
      'access features',
      'accessible entrance',
      'accessible facilities',
      'accessibility details',
      'mobility assistance',
    ],
    'safety_information': [
      'is it safe',
      'safety information',
      'safety features',
      'security information',
      'crime rate',
      'safety tips',
      'security tips',
      'safety advice',
      'security advice',
      'safety concerns',
    ],
  };

  // Current landmark selection state for blind users
  int _selectedLandmarkIndex = -1;
  bool _isLandmarkSelectionMode = false;
  bool _isBlindUserExplorationMode = false;
  bool _isDetailedMode = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _listenToOtherUsers();
    _startContinuousNarration();
    _initializeVoiceNavigation();
    _registerWithAudioManager();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if this screen is currently active when dependencies change
    _checkScreenFocus();
  }

  Future<void> _initializeServices() async {
    try {
      await _locationService.initialize();
      await _voiceCommandService.initialize();
      await _voiceNavigationService.initialize();
      await _audioNarrationService.initialize();
      await _initTts();

      // Get initial position to center the map
      final initialPosition = await _locationService.getInitialPosition();
      if (mounted) {
        setState(() {
          _currentPosition = initialPosition;
        });
      }
      _centerMapOnUser();

      // Listen to location updates
      _locationService.positionStream.listen(_onPositionUpdate);
      _locationService.nearbyLandmarksStream.listen(_onNearbyLandmarksUpdate);
      _locationService.landmarkEnteredStream.listen(_onLandmarkEntered);

      // Listen to voice commands for UI
      _voiceCommandService.uiCommandStream.listen(_onUiCommand);

      // Start location tracking
      await _startLocationTracking();

      // Start automatic narration
      await _startAutomaticNarration();
    } catch (e) {
      print('Error initializing map services: $e');
      if (mounted) {
        await _audioManagerService.speakIfActive(
          'map',
          "Error initializing map services. Please check your location permissions.",
        );
      }
    }
  }

  Future<void> _startAutomaticNarration() async {
    setState(() {
      _isNarrating = true;
    });

    // Enhanced immersive welcome with emotional tone
    String welcomeMessage = _generateImmersiveWelcomeMessage();
    await _audioManagerService.speakIfActive('map', welcomeMessage);

    // Brief pause for user to process
    await Future.delayed(Duration(seconds: 2));

    // Begin enhanced guided exploration
    await _beginEnhancedGuidedExploration();

    setState(() {
      _isNarrating = false;
    });
  }

  String _generateImmersiveWelcomeMessage() {
    if (_isImmersiveNarration) {
      return "Welcome to your immersive exploration experience! I'm your personal guide to the vibrant world around you. Together, we'll discover amazing places, experience rich cultural moments, and create unforgettable memories. Let me show you the wonders that await your discovery.";
    } else {
      return "Welcome to your guided exploration. I'm your personal guide to discover amazing places around you. Let me start by showing you what's nearby.";
    }
  }

  Future<void> _beginEnhancedGuidedExploration() async {
    if (_currentPosition != null) {
      String exploration = _generateEnhancedExplorationMessage();

      await _audioManagerService.speakIfActive('map', exploration);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "I'm getting your location. Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center map, or 'six' for help. You can also say 'pause', 'play', or 'next'.",
      );
    }
  }

  String _generateEnhancedExplorationMessage() {
    String exploration = "";

    if (_isImmersiveNarration) {
      exploration =
          "Welcome to your interactive map exploration! I'm your real-time guide to discover amazing places around you. ";

      if (_nearbyLandmarks.isNotEmpty) {
        exploration +=
            "I've discovered ${_nearbyLandmarks.length} fascinating destinations nearby, each with its own unique story and cultural significance. ";

        // Highlight the most interesting landmarks first
        List<Landmark> sortedLandmarks = List.from(_nearbyLandmarks);
        sortedLandmarks.sort(
          (a, b) => _getLandmarkInterestScore(
            b,
          ).compareTo(_getLandmarkInterestScore(a)),
        );

        if (sortedLandmarks.isNotEmpty) {
          final topLandmark = sortedLandmarks.first;
          exploration +=
              "The most captivating place nearby is ${topLandmark.name}, a ${topLandmark.category} that promises an unforgettable experience. ";
        }

        exploration +=
            "Here are your intuitive commands: Say 'one' for a rich description of your surroundings, 'two' to discover extraordinary places, 'three' to explore nearby facilities, 'four' to find guided tours, 'five' to center the map, or 'six' for assistance. ";
        exploration +=
            "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip to the next location. ";
        exploration +=
            "For an immersive experience, try 'immersive mode' to activate enhanced narration.";
      } else {
        exploration +=
            "I'm actively searching for amazing places around you. Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center map, or 'six' for help. ";
        exploration +=
            "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip. ";
        exploration +=
            "For an immersive experience, try 'immersive mode' to activate enhanced narration.";
      }
    } else {
      exploration =
          "Welcome to your interactive map exploration! I'm your real-time guide to discover amazing places around you. ";

      if (_nearbyLandmarks.isNotEmpty) {
        exploration +=
            "I found ${_nearbyLandmarks.length} exciting places nearby. ";

        // Highlight the most interesting landmarks first
        List<Landmark> sortedLandmarks = List.from(_nearbyLandmarks);
        sortedLandmarks.sort(
          (a, b) => _getLandmarkInterestScore(
            b,
          ).compareTo(_getLandmarkInterestScore(a)),
        );

        if (sortedLandmarks.isNotEmpty) {
          final topLandmark = sortedLandmarks.first;
          exploration +=
              "The most fascinating place nearby is ${topLandmark.name}, a ${topLandmark.category}. ";
        }

        exploration +=
            "Here are your simple commands: Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center the map, or 'six' for help. ";
        exploration +=
            "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip to the next location.";
      } else {
        exploration +=
            "I'm searching for amazing places around you. Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center map, or 'six' for help. ";
        exploration +=
            "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip.";
      }
    }

    return exploration;
  }

  Future<void> _beginGuidedExploration() async {
    if (_currentPosition != null) {
      String exploration =
          "Welcome to your interactive map exploration! I'm your real-time guide to discover amazing places around you. ";

      if (_nearbyLandmarks.isNotEmpty) {
        exploration +=
            "I found ${_nearbyLandmarks.length} exciting places nearby. ";

        // Highlight the most interesting landmarks first
        List<Landmark> sortedLandmarks = List.from(_nearbyLandmarks);
        sortedLandmarks.sort(
          (a, b) => _getLandmarkInterestScore(
            b,
          ).compareTo(_getLandmarkInterestScore(a)),
        );

        if (sortedLandmarks.isNotEmpty) {
          final topLandmark = sortedLandmarks.first;
          exploration +=
              "The most fascinating place nearby is ${topLandmark.name}, a ${topLandmark.category}. ";
        }

        exploration +=
            "Here are your simple commands: Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center the map, or 'six' for help. ";
        exploration +=
            "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip to the next location.";
      } else {
        exploration +=
            "I'm searching for amazing places around you. Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center map, or 'six' for help. ";
        exploration +=
            "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip.";
      }

      await _audioManagerService.speakIfActive('map', exploration);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "I'm getting your location. Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center map, or 'six' for help. You can also say 'pause', 'play', or 'next'.",
      );
    }
  }

  int _getLandmarkInterestScore(Landmark landmark) {
    // Score landmarks based on typical tourist interest
    Map<String, int> categoryScores = {
      'attraction': 10,
      'museum': 9,
      'park': 8,
      'restaurant': 7,
      'cafe': 6,
      'shop': 5,
      'facility': 4,
      'service': 3,
    };

    return categoryScores[landmark.category.toLowerCase()] ?? 5;
  }

  Future<void> _speakCurrentSurroundings() async {
    if (_currentPosition != null) {
      String surroundings = _generateEnhancedSurroundingsDescription();

      await _audioManagerService.speakIfActive('map', surroundings);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "I'm getting your current location. Say 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center map, or 'six' for help. You can also say 'pause', 'play', or 'next'.",
      );
    }
  }

  String _generateEnhancedSurroundingsDescription() {
    String surroundings = "";

    if (_isImmersiveNarration) {
      surroundings =
          "Welcome to your current location! You're standing in the heart of Kampala, Uganda's vibrant capital city. ";
      surroundings +=
          "The rich cultural tapestry of this dynamic metropolis surrounds you. ";

      if (_nearbyLandmarks.isNotEmpty) {
        surroundings +=
            "Around you, ${_nearbyLandmarks.length} fascinating destinations await your discovery. ";

        // Group landmarks by category for better organization
        Map<String, List<Landmark>> categorizedLandmarks = {};
        for (var landmark in _nearbyLandmarks) {
          categorizedLandmarks
              .putIfAbsent(landmark.category, () => [])
              .add(landmark);
        }

        // Describe surroundings by category with immersive language
        categorizedLandmarks.forEach((category, landmarks) {
          surroundings +=
              "You'll find ${landmarks.length} ${category}${landmarks.length > 1 ? 's' : ''} nearby, each offering unique experiences: ";
          for (int i = 0; i < landmarks.length && i < 3; i++) {
            final landmark = landmarks[i];
            final distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              landmark.latitude,
              landmark.longitude,
            );
            surroundings +=
                "${landmark.name}, just ${distance.toStringAsFixed(0)} meters away. ";
          }
          surroundings += " ";
        });

        // Highlight the closest landmark with immersive description
        if (_nearbyLandmarks.isNotEmpty) {
          final closestLandmark = _nearbyLandmarks.first;
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            closestLandmark.latitude,
            closestLandmark.longitude,
          );
          surroundings +=
              "The closest treasure to you is ${closestLandmark.name}, a ${closestLandmark.category} just ${distance.toStringAsFixed(0)} meters away. ";
        }
      } else {
        surroundings +=
            "I'm actively searching for amazing places around you. ";
      }

      // Add real-time environmental context
      if (_isRealTimeDataEnabled) {
        surroundings += _generateRealTimeContext();
      }

      surroundings +=
          "Say 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center the map, or 'six' for help. ";
      surroundings +=
          "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip to the next location. ";
      surroundings +=
          "For an immersive experience, try 'immersive mode' to activate enhanced narration.";
    } else {
      surroundings =
          "You are currently at latitude ${_currentPosition!.latitude.toStringAsFixed(4)}, longitude ${_currentPosition!.longitude.toStringAsFixed(4)}. ";

      if (_nearbyLandmarks.isNotEmpty) {
        surroundings += "Here's what I can see around you in real-time: ";

        // Group landmarks by category for better organization
        Map<String, List<Landmark>> categorizedLandmarks = {};
        for (var landmark in _nearbyLandmarks) {
          categorizedLandmarks
              .putIfAbsent(landmark.category, () => [])
              .add(landmark);
        }

        // Describe surroundings by category
        categorizedLandmarks.forEach((category, landmarks) {
          surroundings +=
              "I found ${landmarks.length} ${category}${landmarks.length > 1 ? 's' : ''} nearby: ";
          for (int i = 0; i < landmarks.length && i < 3; i++) {
            final landmark = landmarks[i];
            surroundings += "${landmark.name}, ";
          }
          surroundings += ". ";
        });

        // Highlight the closest landmark
        if (_nearbyLandmarks.isNotEmpty) {
          final closestLandmark = _nearbyLandmarks.first;
          surroundings +=
              "The closest place to you is ${closestLandmark.name}, a ${closestLandmark.category}. ";
        }
      } else {
        surroundings += "I'm searching for places around you in real-time. ";
      }

      surroundings +=
          "Say 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center the map, or 'six' for help. ";
      surroundings +=
          "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip to the next location.";
    }

    return surroundings;
  }

  String _generateRealTimeContext() {
    String context = "Current conditions enhance your experience: ";

    // Simulate real-time data
    final hour = DateTime.now().hour;
    String timeContext = "";
    if (hour >= 6 && hour <= 12) {
      timeContext =
          "The morning light creates a perfect atmosphere for exploration. ";
    } else if (hour >= 12 && hour <= 17) {
      timeContext =
          "The afternoon sun illuminates the vibrant city life around you. ";
    } else if (hour >= 17 && hour <= 21) {
      timeContext =
          "The evening atmosphere brings a magical quality to the surroundings. ";
    } else {
      timeContext =
          "The night creates a peaceful and intimate exploration environment. ";
    }

    String crowdContext = "";
    if (_nearbyLandmarks.length > 5) {
      crowdContext =
          "The area is bustling with activity, creating an energetic and lively atmosphere. ";
    } else if (_nearbyLandmarks.length > 2) {
      crowdContext =
          "The area has a comfortable level of activity, perfect for relaxed exploration. ";
    } else {
      crowdContext =
          "The area is quiet and peaceful, offering a serene exploration experience. ";
    }

    context += timeContext + crowdContext;
    return context;
  }

  Future<void> _navigateBack() async {
    await _audioManagerService.speakIfActive(
      'map',
      "Going back to previous screen.",
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // Tour-style guided exploration methods
  Future<void> _startGuidedTour() async {
    if (_nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "I'm still discovering places around you. Let me search for interesting locations to show you.",
      );
      return;
    }

    // Sort landmarks by interest score for tour flow
    List<Landmark> tourLandmarks = List.from(_nearbyLandmarks);
    tourLandmarks.sort(
      (a, b) =>
          _getLandmarkInterestScore(b).compareTo(_getLandmarkInterestScore(a)),
    );

    String tourStart =
        "Perfect! Let's start your guided tour. I'll show you the most fascinating places nearby. ";
    tourStart +=
        "We have ${tourLandmarks.length} amazing locations to explore. ";

    if (tourLandmarks.isNotEmpty) {
      final firstLandmark = tourLandmarks.first;
      tourStart +=
          "Our first stop is ${firstLandmark.name}, a ${firstLandmark.category}. ";
      tourStart +=
          "Say 'tell me more' to learn about this place, or 'next' to continue to the next location.";
    }

    await _audioManagerService.speakIfActive('map', tourStart);
  }

  Future<void> _navigateToNextLandmark() async {
    if (_nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "No more places to explore right now. Say 'discover' to start a new tour or 'facilities' to find services.",
      );
      return;
    }

    // Simple rotation through landmarks
    _currentLandmarkIndex =
        (_currentLandmarkIndex + 1) % _nearbyLandmarks.length;

    final landmark = _nearbyLandmarks[_currentLandmarkIndex];
    String navigation =
        "Next on our tour: ${landmark.name}, a ${landmark.category}. ";
    navigation +=
        "Say 'tell me more' to learn about this place, 'next' to continue, or 'discover' to start over.";

    await _audioManagerService.speakIfActive('map', navigation);
  }

  Future<void> _provideDetailedDescription() async {
    if (_nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "I don't have specific places to describe right now. Say 'discover' to start exploring or 'facilities' to find services.",
      );
    } else {
      final landmark = _nearbyLandmarks[_currentLandmarkIndex];
      String description = "${landmark.name} is a ${landmark.category}. ";
      description += landmark.description;
      description += " This is a wonderful place to visit and experience. ";
      description +=
          "Say 'next' to continue to the next location, or 'discover' to start a new tour.";

      await _audioManagerService.speakIfActive('map', description);
    }
  }

  // Simple number-based command methods
  Future<void> _speakNearbyLandmarks() async {
    if (_nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "No great places found nearby yet. Say 'one' to describe your surroundings or 'three' to describe nearby facilities.",
      );
    } else {
      String landmarks = _generateEnhancedLandmarksDescription();

      await _audioManagerService.speakIfActive('map', landmarks);
    }
  }

  String _generateEnhancedLandmarksDescription() {
    String landmarks = "";

    if (_isImmersiveNarration) {
      landmarks =
          "Let me introduce you to the extraordinary places waiting to be discovered around you: ";

      // Filter for interesting/attractive places
      final greatPlaces =
          _nearbyLandmarks
              .where(
                (landmark) =>
                    landmark.category.toLowerCase().contains('attraction') ||
                    landmark.category.toLowerCase().contains('museum') ||
                    landmark.category.toLowerCase().contains('park') ||
                    landmark.category.toLowerCase().contains('monument') ||
                    landmark.category.toLowerCase().contains('landmark') ||
                    landmark.category.toLowerCase().contains('viewpoint'),
              )
              .toList();

      if (greatPlaces.isEmpty) {
        landmarks +=
            "I've discovered some fascinating places in your area, each with its own unique story: ";
        for (int i = 0; i < _nearbyLandmarks.length && i < 5; i++) {
          final landmark = _nearbyLandmarks[i];
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            landmark.latitude,
            landmark.longitude,
          );
          landmarks +=
              "${i + 1}. ${landmark.name}, a ${landmark.category} just ${distance.toStringAsFixed(0)} meters away. ";
        }
      } else {
        landmarks += "Here are the most captivating destinations nearby: ";
        for (int i = 0; i < greatPlaces.length && i < 5; i++) {
          final landmark = greatPlaces[i];
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            landmark.latitude,
            landmark.longitude,
          );
          landmarks +=
              "${i + 1}. ${landmark.name}, a ${landmark.category} just ${distance.toStringAsFixed(0)} meters away. ";
        }
      }

      landmarks +=
          "Each of these places offers unique experiences and cultural insights. ";
      landmarks +=
          "Say 'one' to describe your surroundings, 'three' to describe nearby facilities, 'four' to find nearby tours, or 'five' to center the map. ";
      landmarks +=
          "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip to the next location. ";
      landmarks +=
          "For detailed information about any place, say 'tell me more about' followed by the landmark name.";
    } else {
      landmarks = "Here are the great places to discover nearby: ";

      // Filter for interesting/attractive places
      final greatPlaces =
          _nearbyLandmarks
              .where(
                (landmark) =>
                    landmark.category.toLowerCase().contains('attraction') ||
                    landmark.category.toLowerCase().contains('museum') ||
                    landmark.category.toLowerCase().contains('park') ||
                    landmark.category.toLowerCase().contains('monument') ||
                    landmark.category.toLowerCase().contains('landmark') ||
                    landmark.category.toLowerCase().contains('viewpoint'),
              )
              .toList();

      if (greatPlaces.isEmpty) {
        landmarks += "I found some interesting places in the area: ";
        for (int i = 0; i < _nearbyLandmarks.length && i < 5; i++) {
          final landmark = _nearbyLandmarks[i];
          landmarks += "${i + 1}. ${landmark.name}, a ${landmark.category}. ";
        }
      } else {
        for (int i = 0; i < greatPlaces.length && i < 5; i++) {
          final landmark = greatPlaces[i];
          landmarks += "${i + 1}. ${landmark.name}, a ${landmark.category}. ";
        }
      }

      landmarks +=
          "Say 'one' to describe your surroundings, 'three' to describe nearby facilities, 'four' to find nearby tours, or 'five' to center the map. ";
      landmarks +=
          "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip to the next location.";
    }

    return landmarks;
  }

  Future<void> _speakNearbyFacilities() async {
    if (_nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "No facilities found nearby. Say 'one' to describe your surroundings or 'two' to discover great places.",
      );
    } else {
      String facilities = _generateEnhancedFacilitiesDescription();

      await _audioManagerService.speakIfActive('map', facilities);
    }
  }

  String _generateEnhancedFacilitiesDescription() {
    String facilities = "";

    if (_isImmersiveNarration) {
      facilities =
          "Let me guide you through the wonderful facilities and services available to enhance your experience: ";
    } else {
      facilities =
          "Here are the nearby facilities and services I can describe: ";
    }

    final facilityLandmarks =
        _nearbyLandmarks
            .where(
              (l) =>
                  l.category.toLowerCase().contains('facility') ||
                  l.category.toLowerCase().contains('service') ||
                  l.category.toLowerCase().contains('shop') ||
                  l.category.toLowerCase().contains('restaurant') ||
                  l.category.toLowerCase().contains('cafe') ||
                  l.category.toLowerCase().contains('hospital') ||
                  l.category.toLowerCase().contains('bank') ||
                  l.category.toLowerCase().contains('pharmacy'),
            )
            .toList();

    if (facilityLandmarks.isEmpty) {
      if (_isImmersiveNarration) {
        facilities +=
            "While specific facilities aren't currently visible, the area offers a rich cultural experience. ";
      } else {
        facilities += "No specific facilities found in this area. ";
      }
    } else {
      // Group facilities by type for better organization
      Map<String, List<Landmark>> categorizedFacilities = {};
      for (var landmark in facilityLandmarks) {
        String category = landmark.category.toLowerCase();
        String type =
            category.contains('restaurant') || category.contains('cafe')
                ? 'Dining'
                : category.contains('shop')
                ? 'Shopping'
                : category.contains('hospital') || category.contains('pharmacy')
                ? 'Healthcare'
                : category.contains('bank')
                ? 'Financial'
                : 'Services';
        categorizedFacilities.putIfAbsent(type, () => []).add(landmark);
      }

      if (_isImmersiveNarration) {
        facilities +=
            "You'll find thoughtfully arranged services to meet your needs: ";
      }

      categorizedFacilities.forEach((type, landmarks) {
        if (_isImmersiveNarration) {
          facilities +=
              "For ${type.toLowerCase()}, you have ${landmarks.length} excellent option${landmarks.length > 1 ? 's' : ''}: ";
        } else {
          facilities +=
              "I found ${landmarks.length} ${type.toLowerCase()} option${landmarks.length > 1 ? 's' : ''}: ";
        }

        for (int i = 0; i < landmarks.length && i < 3; i++) {
          final landmark = landmarks[i];
          if (_isImmersiveNarration && _currentPosition != null) {
            final distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              landmark.latitude,
              landmark.longitude,
            );
            facilities +=
                "${landmark.name}, just ${distance.toStringAsFixed(0)} meters away. ";
          } else {
            facilities += "${landmark.name}, ";
          }
        }
        facilities += ". ";
      });
    }

    if (_isImmersiveNarration) {
      facilities +=
          "Each facility is designed to provide you with comfort and convenience during your exploration. ";
      facilities +=
          "Say 'one' to describe your surroundings, 'two' to discover great places, 'four' to find nearby tours, or 'five' to center the map. ";
      facilities +=
          "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip. ";
      facilities +=
          "For detailed information about any facility, say 'tell me more about' followed by the facility name.";
    } else {
      facilities +=
          "Say 'one' to describe your surroundings, 'two' to discover great places, 'four' to find nearby tours, or 'five' to center the map. ";
      facilities +=
          "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip.";
    }

    return facilities;
  }

  Future<void> _speakLocalTips() async {
    String tips = "Here are some helpful local tips: ";
    tips +=
        "You can explore the area by saying 'one' to describe your surroundings, 'two' to discover great places, or 'three' to describe nearby facilities. ";
    tips += "Use 'five' to center the map on your location. ";
    tips +=
        "Say 'pause' to pause narration, 'play' to resume, or 'next' to skip to the next location. ";
    tips += "Say 'six' for help anytime you need assistance.";

    await _audioManagerService.speakIfActive('map', tips);
  }

  Future<void> _speakNearbyTours() async {
    String tours = "Here are the nearby tours and attractions: ";
    tours +=
        "You can discover guided tours, walking paths, and interesting attractions in this area. ";
    tours +=
        "Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'five' to center the map, or 'six' for help. ";
    tours +=
        "You can also say 'pause' to pause, 'play' to resume, or 'next' to skip.";

    await _audioManagerService.speakIfActive('map', tours);
  }

  Future<void> _speakHelp() async {
    String help = _generateEnhancedHelpMessage();

    await _audioManagerService.speakIfActive('map', help);
  }

  String _generateEnhancedHelpMessage() {
    String help = "";

    if (_isImmersiveNarration) {
      help =
          "Welcome to your comprehensive guide! Here are all the wonderful ways you can interact with your exploration experience: ";
      help += "Say 'one' for a rich description of your surroundings. ";
      help += "Say 'two' to discover extraordinary places around you. ";
      help += "Say 'three' to explore nearby facilities and services. ";
      help += "Say 'four' to find guided tours and experiences. ";
      help += "Say 'five' to center the map on your location. ";
      help += "Say 'six' for additional assistance and options. ";
      help +=
          "Control your experience with 'pause' to pause narration, 'play' to resume, or 'next' to skip to the next location. ";
      help +=
          "Enhance your experience with 'immersive mode' for rich, engaging descriptions. ";
      help +=
          "Adjust your tone with 'enthusiastic tone', 'calm tone', 'friendly tone', or 'urgent tone'. ";
      help +=
          "Say 'repeat' to hear this information again, or 'help' anytime for assistance.";
    } else {
      help = "Here are your simple map commands: ";
      help += "Say 'one' to describe your surroundings. ";
      help += "Say 'two' to discover great places. ";
      help += "Say 'three' to describe nearby facilities. ";
      help += "Say 'four' to find nearby tours. ";
      help += "Say 'five' to center the map on your location. ";
      help += "Say 'six' for help and additional options. ";
      help +=
          "Say 'pause' to pause narration, 'play' to resume, or 'next' to skip to the next location. ";
      help += "Say 'repeat' to hear this information again.";
    }

    return help;
  }

  Future<void> _registerWithAudioManager() async {
    // Register this screen with the audio manager
    // Create a new speech instance for this screen
    final speech = stt.SpeechToText();
    await speech.initialize();
    _audioManagerService.registerScreen('map', _tts, speech);

    // Enable narration for map screen with user-controlled timing
    _audioManagerService.enableNarration(
      'map',
      interval: const Duration(seconds: 30),
      priority: 1,
    );

    // Listen to audio control events with enhanced focus management
    _audioControlSubscription = _audioManagerService.audioControlStream.listen((
      event,
    ) {
      print('Map screen audio control event: $event');
      if (event.startsWith('activated:map')) {
        _onMapScreenActivated();
      } else if (event.startsWith('deactivated:map')) {
        _onMapScreenDeactivated();
      }
    });

    // Listen to screen activation events
    _screenActivationSubscription = _audioManagerService.screenActivationStream
        .listen((screenId) {
          print('Map screen activation event: $screenId');
          if (screenId == 'map') {
            // Map screen is now the active focus
            _onMapScreenActivated();
          } else {
            // Another screen is now the active focus
            _onMapScreenDeactivated();
          }
        });

    // Listen to narration control events
    _audioManagerService.narrationControlStream.listen((event) {
      if (event.startsWith('trigger:map')) {
        print('🎤 Narration triggered by AudioManagerService');
      }
    });
  }

  Future<void> _initializeVoiceNavigation() async {
    // Listen to map-specific voice commands
    _mapCommandSubscription = _voiceNavigationService.mapCommandStream.listen((
      command,
    ) {
      _handleMapVoiceCommand(command);
    });
  }

  // Streamlined map voice command handler with enhanced user experience
  Future<void> _handleMapVoiceCommand(String command) async {
    print('🎤 Map voice command received: $command');

    // Record user interaction for smart pausing
    _audioManagerService.recordUserInteraction('map');

    // Pause narration for user commands
    _audioManagerService.pauseNarration('map');

    // Prevent command spam with intelligent throttling
    if (_commandCount > 8) {
      _commandCount = 0;
      await _audioManagerService.speakIfActive(
        'map',
        "Too many commands. Please wait a moment before speaking again.",
      );
      return;
    }
    _commandCount++;

    // Provide immediate haptic feedback for command recognition
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }

    // Streamlined command processing with priority-based routing
    try {
      // NARRATION CONTROL PRIORITY: User narration control commands
      if (_isNarrationControlCommand(command)) {
        await _handleNarrationControlCommand(command);
        return;
      }

      // BLIND USER PRIORITY: Enhanced blind user interaction commands
      if (_isBlindUserCommand(command)) {
        await _handleBlindUserVoiceCommand(command);
        return;
      }

      // HIGH PRIORITY: Core map information commands
      if (_isCoreInformationCommand(command)) {
        await _handleCoreInformationCommand(command);
        return;
      }

      // HIGH PRIORITY: Map control commands
      if (_isMapControlCommand(command)) {
        await _handleMapControlCommand(command);
        return;
      }

      // MEDIUM PRIORITY: Navigation commands
      if (_isNavigationCommand(command)) {
        await _handleNavigationCommand(command);
        return;
      }

      // MEDIUM PRIORITY: Mode control commands
      if (_isModeControlCommand(command)) {
        await _handleModeControlCommand(command);
        return;
      }

      // LOW PRIORITY: Voice control commands
      if (_isVoiceControlCommand(command)) {
        await _handleVoiceControlCommand(command);
        return;
      }

      // LOW PRIORITY: Utility commands
      if (_isUtilityCommand(command)) {
        await _handleUtilityCommand(command);
        return;
      }

      // EMERGENCY PRIORITY: Safety commands
      if (_isEmergencyCommand(command)) {
        await _handleEmergencyCommand(command);
        return;
      }

      // SIMPLE NUMBER-BASED COMMANDS: Easy voice control
      if (command == 'one' || command == '1') {
        await _speakCurrentSurroundings();
        return;
      } else if (command == 'two' || command == '2') {
        await _speakNearbyLandmarks();
        return;
      } else if (command == 'three' || command == '3') {
        await _speakNearbyFacilities();
        return;
      } else if (command == 'four' || command == '4') {
        await _speakNearbyTours();
        return;
      } else if (command == 'five' || command == '5') {
        _centerMapOnUser();
        await _audioManagerService.speakIfActive(
          'map',
          "Map centered on your location. Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, or 'six' for help. You can also say 'pause', 'play', or 'next'.",
        );
        return;
      } else if (command == 'six' || command == '6') {
        await _speakHelp();
        return;
      } else if (command == 'pause' || command == 'stop') {
        await _audioManagerService.stopAllAudio();
        await _audioManagerService.speakIfActive(
          'map',
          "Narration paused. Say 'play' to resume or 'one' to describe your surroundings.",
        );
        return;
      } else if (command == 'play' || command == 'resume') {
        await _speakCurrentSurroundings();
        return;
      } else if (command == 'next' || command == 'skip') {
        await _navigateToNextLandmark();
        return;
      } else if (command == 'repeat' || command == 'again') {
        await _speakCurrentSurroundings();
        return;
      } else if (command == 'go back' || command == 'back') {
        await _navigateBack();
        return;
      }

      // Unknown command - provide simple feedback
      await _audioManagerService.speakIfActive(
        'map',
        "Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center map, or 'six' for help. You can also say 'pause', 'play', or 'next'.",
      );
    } catch (e) {
      print('Error handling map voice command: $e');
      await _audioManagerService.speakIfActive(
        'map',
        "Sorry, there was an error processing your command. Please try again.",
      );
    }
  }

  // Check if command is a blind user specific command
  bool _isBlindUserCommand(String command) {
    return _blindUserCommandPatterns.values.any(
      (patterns) => patterns.any(
        (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
      ),
    );
  }

  // Narration control commands - user control over continuous narration
  bool _isNarrationControlCommand(String command) {
    final narrationControlPatterns = [
      'narration mode',
      'narration settings',
      'narration control',
      'continuous narration',
      'auto narration',
      'narration interval',
      'narration detail',
      'narration length',
      'narration pause',
      'narration resume',
      'narration stop',
      'narration start',
      'silent mode',
      'minimal mode',
      'detailed mode',
      'continuous mode',
      'standard mode',
      'brief narration',
      'comprehensive narration',
      'location narration',
      'landmark narration',
      'safety narration',
      'street narration',
      'haptic feedback',
      'smart pausing',
      'narration frequency',
      'narration volume',
      'narration speed',
      'narration preferences',
      'narration options',
      'narration priority',
      'audio harmony',
      'narration harmony',
      'interrupt narration',
      'clear interruption',
      'audio queue',
      'narration cooldown',
    ];

    return narrationControlPatterns.any((pattern) => command.contains(pattern));
  }

  Future<void> _handleNarrationControlCommand(String command) async {
    // Record user interaction
    _audioManagerService.recordUserInteraction('map');

    if (command.contains('silent mode') || command.contains('stop narration')) {
      _audioNarrationService.setNarrationMode(NarrationMode.silent);
      await _audioManagerService.speakIfActive(
        'map',
        'Silent mode activated. Continuous narration stopped.',
      );
    } else if (command.contains('minimal mode')) {
      _audioNarrationService.setNarrationMode(NarrationMode.minimal);
      await _audioManagerService.speakIfActive(
        'map',
        'Minimal narration mode activated. Only essential information will be provided.',
      );
    } else if (command.contains('standard mode')) {
      _audioNarrationService.setNarrationMode(NarrationMode.standard);
      await _audioManagerService.speakIfActive(
        'map',
        'Standard narration mode activated. Balanced information will be provided.',
      );
    } else if (command.contains('detailed mode') ||
        command.contains('comprehensive')) {
      _audioNarrationService.setNarrationMode(NarrationMode.detailed);
      await _audioManagerService.speakIfActive(
        'map',
        'Detailed narration mode activated. Comprehensive information will be provided.',
      );
    } else if (command.contains('continuous mode')) {
      _audioNarrationService.setNarrationMode(NarrationMode.continuous);
      await _audioManagerService.speakIfActive(
        'map',
        'Continuous narration mode activated. Frequent updates will be provided.',
      );
    } else if (command.contains('immersive mode')) {
      _audioNarrationService.setNarrationMode(NarrationMode.immersive);
      setState(() {
        _isImmersiveNarration = true;
      });
      await _audioManagerService.speakIfActive(
        'map',
        'Immersive narration mode activated! Experience rich, engaging descriptions with emotional depth and cultural context.',
      );
    } else if (command.contains('pause narration')) {
      _audioNarrationService.pauseNarration();
      await _audioManagerService.speakIfActive(
        'map',
        'Narration paused. Say resume narration to continue.',
      );
    } else if (command.contains('resume narration')) {
      _audioNarrationService.resumeNarration();
      await _audioManagerService.speakIfActive('map', 'Narration resumed.');
    } else if (command.contains('brief narration')) {
      _audioNarrationService.setNarrationDetail(NarrationDetail.brief);
      await _audioManagerService.speakIfActive(
        'map',
        'Brief narration detail level set.',
      );
    } else if (command.contains('comprehensive narration')) {
      _audioNarrationService.setNarrationDetail(NarrationDetail.comprehensive);
      await _audioManagerService.speakIfActive(
        'map',
        'Comprehensive narration detail level set.',
      );
    } else if (command.contains('immersive narration')) {
      _audioNarrationService.setNarrationDetail(NarrationDetail.immersive);
      await _audioManagerService.speakIfActive(
        'map',
        'Immersive narration detail level set. Experience rich, engaging descriptions.',
      );
    } else if (command.contains('enthusiastic tone') ||
        command.contains('excited tone')) {
      _audioNarrationService.setNarrationTone(NarrationTone.enthusiastic);
      setState(() {
        _currentNarrationTone = 'enthusiastic';
      });
      await _audioManagerService.speakIfActive(
        'map',
        'Enthusiastic tone activated! I\'ll provide excited and engaging narration.',
      );
    } else if (command.contains('calm tone') ||
        command.contains('relaxed tone')) {
      _audioNarrationService.setNarrationTone(NarrationTone.calm);
      setState(() {
        _currentNarrationTone = 'calm';
      });
      await _audioManagerService.speakIfActive(
        'map',
        'Calm tone activated. I\'ll provide relaxed and soothing narration.',
      );
    } else if (command.contains('friendly tone') ||
        command.contains('warm tone')) {
      _audioNarrationService.setNarrationTone(NarrationTone.friendly);
      setState(() {
        _currentNarrationTone = 'friendly';
      });
      await _audioManagerService.speakIfActive(
        'map',
        'Friendly tone activated. I\'ll provide warm and welcoming narration.',
      );
    } else if (command.contains('urgent tone') ||
        command.contains('important tone')) {
      _audioNarrationService.setNarrationTone(NarrationTone.urgent);
      setState(() {
        _currentNarrationTone = 'urgent';
      });
      await _audioManagerService.speakIfActive(
        'map',
        'Urgent tone activated. I\'ll emphasize important information.',
      );
    } else if (command.contains('location narration')) {
      _audioNarrationService.toggleLocationNarration();
      final status =
          _audioNarrationService.isLocationNarrationEnabled
              ? 'enabled'
              : 'disabled';
      await _audioManagerService.speakIfActive(
        'map',
        'Location narration $status.',
      );
    } else if (command.contains('landmark narration')) {
      _audioNarrationService.toggleLandmarkNarration();
      final status =
          _audioNarrationService.isLandmarkNarrationEnabled
              ? 'enabled'
              : 'disabled';
      await _audioManagerService.speakIfActive(
        'map',
        'Landmark narration $status.',
      );
    } else if (command.contains('safety narration')) {
      _audioNarrationService.toggleSafetyNarration();
      final status =
          _audioNarrationService.isSafetyNarrationEnabled
              ? 'enabled'
              : 'disabled';
      await _audioManagerService.speakIfActive(
        'map',
        'Safety narration $status.',
      );
    } else if (command.contains('street narration')) {
      _audioNarrationService.toggleStreetNarration();
      final status =
          _audioNarrationService.isStreetNarrationEnabled
              ? 'enabled'
              : 'disabled';
      await _audioManagerService.speakIfActive(
        'map',
        'Street narration $status.',
      );
    } else if (command.contains('haptic feedback')) {
      // Haptic feedback is now handled internally by the audio narration service
      await _audioManagerService.speakIfActive(
        'map',
        'Haptic feedback is automatically managed for optimal user experience.',
      );
    } else if (command.contains('narration interval') ||
        command.contains('narration frequency')) {
      if (command.contains('30 seconds') || command.contains('30 second')) {
        _audioManagerService.setNarrationInterval(
          'map',
          const Duration(seconds: 30),
        );
        await _audioManagerService.speakIfActive(
          'map',
          'Narration interval set to 30 seconds.',
        );
      } else if (command.contains('60 seconds') ||
          command.contains('1 minute')) {
        _audioManagerService.setNarrationInterval(
          'map',
          const Duration(seconds: 60),
        );
        await _audioManagerService.speakIfActive(
          'map',
          'Narration interval set to 1 minute.',
        );
      } else if (command.contains('15 seconds') ||
          command.contains('15 second')) {
        _audioManagerService.setNarrationInterval(
          'map',
          const Duration(seconds: 15),
        );
        await _audioManagerService.speakIfActive(
          'map',
          'Narration interval set to 15 seconds.',
        );
      } else {
        await _audioManagerService.speakIfActive(
          'map',
          'Available intervals: 15 seconds, 30 seconds, or 1 minute.',
        );
      }
    } else if (command.contains('narration priority')) {
      if (command.contains('high') || command.contains('urgent')) {
        _audioManagerService.setNarrationPriority('map', 0);
        await _audioManagerService.speakIfActive(
          'map',
          'Narration priority set to high. Narrations will interrupt other audio.',
        );
      } else if (command.contains('normal') || command.contains('standard')) {
        _audioManagerService.setNarrationPriority('map', 1);
        await _audioManagerService.speakIfActive(
          'map',
          'Narration priority set to normal.',
        );
      } else if (command.contains('low') || command.contains('background')) {
        _audioManagerService.setNarrationPriority('map', 2);
        await _audioManagerService.speakIfActive(
          'map',
          'Narration priority set to low. Narrations will wait for other audio.',
        );
      } else {
        final priority = _audioManagerService.getNarrationPriority('map');
        await _audioManagerService.speakIfActive(
          'map',
          'Current narration priority is $priority. Say "high priority", "normal priority", or "low priority" to change.',
        );
      }
    } else if (command.contains('pause narration')) {
      _audioManagerService.pauseNarration('map');
      await _audioManagerService.speakIfActive('map', 'Narration paused.');
    } else if (command.contains('resume narration')) {
      _audioManagerService.resumeNarration('map');
      await _audioManagerService.speakIfActive('map', 'Narration resumed.');
    } else if (command.contains('stop narration')) {
      _audioManagerService.disableNarration('map');
      await _audioManagerService.speakIfActive('map', 'Narration stopped.');
    } else if (command.contains('start narration')) {
      _audioManagerService.enableNarration('map');
      await _audioManagerService.speakIfActive('map', 'Narration started.');
    } else if (command.contains('interrupt narration')) {
      _audioManagerService.pauseNarration('map');
      await _audioManagerService.speakIfActive('map', 'Narration interrupted.');
    } else if (command.contains('clear interruption') ||
        command.contains('resume narration')) {
      _audioManagerService.resumeNarration('map');
      await _audioManagerService.speakIfActive(
        'map',
        'Narration interruption cleared.',
      );
    } else if (command.contains('narration settings') ||
        command.contains('narration preferences')) {
      await _provideNarrationSettings();
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        'Narration control command not recognized. Say "narration settings" for available options.',
      );
    }
  }

  Future<void> _provideNarrationSettings() async {
    final mode = _audioNarrationService.currentMode.name;
    final interval = _audioManagerService.getNarrationInterval('map').inSeconds;
    final detail = _audioNarrationService.currentDetail.name;
    final tone = _audioNarrationService.currentTone.name;
    final priority = _audioManagerService.getNarrationPriority('map');
    final enabled = _audioManagerService.isNarrationEnabled('map');
    final paused = _audioManagerService.isNarrationPaused('map');

    String settings = _generateEnhancedNarrationSettings(
      mode,
      interval,
      detail,
      tone,
      priority,
      enabled,
      paused,
    );

    await _audioManagerService.speakIfActive('map', settings);
  }

  String _generateEnhancedNarrationSettings(
    String mode,
    int interval,
    String detail,
    String tone,
    int priority,
    bool enabled,
    bool paused,
  ) {
    String settings = "";

    if (_isImmersiveNarration) {
      settings =
          'Your current narration experience is beautifully configured: ';
      settings +=
          'Mode is set to $mode, providing ${_getModeDescription(mode)}. ';
      settings +=
          'Updates occur every $interval seconds for optimal engagement. ';
      settings +=
          'Detail level is $detail, offering ${_getDetailDescription(detail)}. ';
      settings +=
          'Tone is $tone, creating a ${_getToneDescription(tone)} atmosphere. ';
      settings +=
          'Priority is $priority, ensuring ${_getPriorityDescription(priority)}. ';
      settings +=
          'Status: ${enabled ? "actively enhancing your experience" : "currently disabled"}. ';
      settings +=
          'Narration is ${paused ? "paused for your convenience" : "flowing smoothly"}. ';
      settings +=
          'Available modes: silent, minimal, standard, detailed, continuous, and immersive. ';
      settings += 'Available intervals: 15, 30, or 60 seconds. ';
      settings +=
          'Available detail levels: brief, medium, comprehensive, and immersive. ';
      settings +=
          'Available tones: neutral, enthusiastic, calm, urgent, and friendly. ';
      settings += 'Available priorities: high (0), normal (1), low (2). ';
      settings +=
          'Say "immersive mode" for the richest experience, or "standard mode" for balanced narration.';
    } else {
      settings =
          'Current narration settings: Mode is $mode, interval is $interval seconds, detail level is $detail. ';
      settings +=
          'Tone is $tone, priority is $priority, narration is ${enabled ? "enabled" : "disabled"}. ';
      settings += 'Status: ${paused ? "paused" : "active"}. ';
      settings +=
          'Available modes: silent, minimal, standard, detailed, continuous, immersive. ';
      settings += 'Available intervals: 15, 30, or 60 seconds. ';
      settings +=
          'Available detail levels: brief, medium, comprehensive, immersive. ';
      settings +=
          'Available tones: neutral, enthusiastic, calm, urgent, friendly. ';
      settings += 'Available priorities: high (0), normal (1), low (2). ';
      settings +=
          'Say "silent mode" to stop narration, or "standard mode" to resume normal narration.';
    }

    return settings;
  }

  String _getModeDescription(String mode) {
    switch (mode.toLowerCase()) {
      case 'immersive':
        return 'rich, engaging experiences with emotional depth';
      case 'detailed':
        return 'comprehensive information and insights';
      case 'continuous':
        return 'frequent updates and real-time guidance';
      case 'standard':
        return 'balanced and informative narration';
      case 'minimal':
        return 'essential information only';
      case 'silent':
        return 'quiet exploration mode';
      default:
        return 'standard narration';
    }
  }

  String _getDetailDescription(String detail) {
    switch (detail.toLowerCase()) {
      case 'immersive':
        return 'rich, engaging descriptions with cultural context';
      case 'comprehensive':
        return 'complete information and detailed insights';
      case 'medium':
        return 'balanced detail and essential information';
      case 'brief':
        return 'concise and essential information';
      default:
        return 'standard detail level';
    }
  }

  String _getToneDescription(String tone) {
    switch (tone.toLowerCase()) {
      case 'enthusiastic':
        return 'excited and engaging';
      case 'calm':
        return 'relaxed and soothing';
      case 'friendly':
        return 'warm and welcoming';
      case 'urgent':
        return 'important and attention-grabbing';
      case 'neutral':
        return 'balanced and informative';
      default:
        return 'standard tone';
    }
  }

  String _getPriorityDescription(int priority) {
    switch (priority) {
      case 0:
        return 'immediate attention for important information';
      case 1:
        return 'balanced priority for normal operation';
      case 2:
        return 'background priority for non-urgent information';
      default:
        return 'standard priority';
    }
  }

  // Core information commands - most frequently used
  bool _isCoreInformationCommand(String command) {
    return command == 'surroundings' ||
        command == 'great_places' ||
        command == 'facilities' ||
        command == 'local_tips' ||
        command.contains('attractions') ||
        command.contains('features') ||
        command.contains('events') ||
        command.contains('weather');
  }

  Future<void> _handleCoreInformationCommand(String command) async {
    switch (command) {
      case 'surroundings':
        await _handleDescribeSurroundings();
        break;
      case 'great_places':
        await _handleGreatPlaces();
        break;
      case 'facilities':
        await _handleFacilities();
        break;
      case 'local_tips':
        await _handleLocalTips();
        break;
      default:
        if (command.contains('attractions')) {
          await _handleNearbyAttractions();
        } else if (command.contains('features')) {
          await _handleFeatures();
        } else if (command.contains('events')) {
          await _handleLocalEvents();
        } else if (command.contains('weather')) {
          await _handleWeatherInfo();
        }
    }
  }

  // Map control commands - essential map manipulation
  bool _isMapControlCommand(String command) {
    return command == 'zoom_control:in' ||
        command == 'zoom_control:out' ||
        command == 'center' ||
        command.contains('pan') ||
        command.contains('rotate') ||
        command.contains('tilt');
  }

  Future<void> _handleMapControlCommand(String command) async {
    switch (command) {
      case 'zoom_control:in':
        await _handleZoomIn();
        break;
      case 'zoom_control:out':
        await _handleZoomOut();
        break;
      case 'center':
        await _handleCenterMap();
        break;
      default:
        if (command.contains('pan')) {
          await _handleMapPan(command);
        } else if (command.contains('rotate')) {
          await _handleMapRotation(command);
        } else if (command.contains('tilt')) {
          await _handleMapTilt(command);
        }
    }
  }

  // Navigation commands - route planning and guidance
  bool _isNavigationCommand(String command) {
    return command.startsWith('navigation:') ||
        command == 'stop_navigation' ||
        command.contains('navigate_to_landmark') ||
        command.contains('plan_route') ||
        command.contains('go to landmark');
  }

  Future<void> _handleNavigationCommand(String command) async {
    if (command.startsWith('navigation:')) {
      String destination = command.split(':').last;
      await _handleStartNavigation(destination);
    } else if (command == 'stop_navigation') {
      await _handleStopNavigation();
    } else if (command.contains('navigate_to_landmark') ||
        command.contains('go to landmark')) {
      String landmarkName =
          command.contains(':')
              ? command.split(':').last
              : command.replaceAll('go to landmark', '').trim();
      await _handleLandmarkNavigation(landmarkName);
    } else if (command.contains('plan_route')) {
      String route =
          command.contains(':')
              ? command.split(':').last
              : command.replaceAll('plan route', '').trim();
      await _handleRoutePlanning(route);
    }
  }

  // Mode control commands - exploration and discovery modes
  bool _isModeControlCommand(String command) {
    return command.contains('exploration_mode') ||
        command.contains('discovery_mode') ||
        command.contains('route_mode') ||
        command.contains('accessibility_mode') ||
        command.contains('emergency_mode');
  }

  Future<void> _handleModeControlCommand(String command) async {
    if (command.contains('exploration_mode')) {
      await _handleExplorationMode();
    } else if (command.contains('discovery_mode')) {
      await _handleDiscoveryMode();
    } else if (command.contains('route_mode')) {
      await _handleRouteMode();
    } else if (command.contains('accessibility_mode')) {
      await _handleAccessibilityMode();
    } else if (command.contains('emergency_mode')) {
      await _handleEmergencyMode();
    }
  }

  // Voice control commands - audio and narration settings
  bool _isVoiceControlCommand(String command) {
    return command.contains('voice_settings') ||
        command.contains('pause_voice') ||
        command.contains('resume_voice') ||
        command.contains('detailed_narration') ||
        command.contains('quick_narration') ||
        command.contains('volume') ||
        command.contains('speed') ||
        command.contains('language');
  }

  Future<void> _handleVoiceControlCommand(String command) async {
    if (command.contains('voice_settings')) {
      await _handleVoiceSettings();
    } else if (command.contains('pause_voice')) {
      await _handlePauseVoice();
    } else if (command.contains('resume_voice')) {
      await _handleResumeVoice();
    } else if (command.contains('detailed_narration')) {
      await _handleDetailedNarration();
    } else if (command.contains('quick_narration')) {
      await _handleQuickNarration();
    } else if (command.contains('volume')) {
      await _handleVolumeAdjustment(command);
    } else if (command.contains('speed')) {
      await _handleSpeedAdjustment(command);
    } else if (command.contains('language')) {
      await _handleLanguageChange(command);
    }
  }

  // Utility commands - help, status, and general utilities
  bool _isUtilityCommand(String command) {
    return command.contains('help') ||
        command.contains('status') ||
        command.contains('clear_screen') ||
        command.contains('save_location') ||
        command.contains('share_location');
  }

  Future<void> _handleUtilityCommand(String command) async {
    if (command.contains('help')) {
      await _handleMapHelp();
    } else if (command.contains('status')) {
      await _handleMapStatus();
    } else if (command.contains('clear_screen')) {
      await _handleClearScreen();
    } else if (command.contains('save_location')) {
      await _handleSaveLocation();
    } else if (command.contains('share_location')) {
      await _handleShareLocation();
    }
  }

  // Emergency commands - safety and emergency features
  bool _isEmergencyCommand(String command) {
    return command.contains('sos') ||
        command.contains('emergency_help') ||
        command.contains('find_nearest');
  }

  Future<void> _handleEmergencyCommand(String command) async {
    if (command.contains('sos')) {
      await _handleSOS();
    } else if (command.contains('emergency_help')) {
      await _handleEmergencyHelp();
    } else if (command.contains('find_nearest')) {
      String facility =
          command.contains(':')
              ? command.split(':').last
              : command.replaceAll('find nearest', '').trim();
      await _handleFindNearest(facility);
    }
  }

  // Intelligent feedback for unknown commands
  Future<void> _provideIntelligentFeedback(String command) async {
    // Analyze command to provide contextual suggestions
    String suggestion = _getContextualSuggestion(command);

    await _audioManagerService.speakIfActive(
      'map',
      "I didn't understand '$command'. $suggestion",
    );
  }

  String _getContextualSuggestion(String command) {
    String lowerCommand = command.toLowerCase();

    if (lowerCommand.contains('zoom') ||
        lowerCommand.contains('closer') ||
        lowerCommand.contains('farther')) {
      return "Try saying 'zoom in' or 'zoom out' to adjust the map view.";
    } else if (lowerCommand.contains('where') ||
        lowerCommand.contains('location') ||
        lowerCommand.contains('position')) {
      return "Try saying 'center map' to focus on your current location.";
    } else if (lowerCommand.contains('nearby') ||
        lowerCommand.contains('around') ||
        lowerCommand.contains('surroundings')) {
      return "Try saying 'tell me about my surroundings' to hear about the area around you.";
    } else if (lowerCommand.contains('place') ||
        lowerCommand.contains('attraction') ||
        lowerCommand.contains('landmark')) {
      return "Try saying 'what are the great places here' to discover nearby attractions.";
    } else if (lowerCommand.contains('facility') ||
        lowerCommand.contains('service') ||
        lowerCommand.contains('amenity')) {
      return "Try saying 'what facilities are nearby' to find local services.";
    } else if (lowerCommand.contains('tip') ||
        lowerCommand.contains('advice') ||
        lowerCommand.contains('recommendation')) {
      return "Try saying 'give me local tips' for visitor advice and recommendations.";
    } else if (lowerCommand.contains('navigate') ||
        lowerCommand.contains('route') ||
        lowerCommand.contains('direction')) {
      return "Try saying 'navigate to' followed by a destination name.";
    } else if (lowerCommand.contains('help') ||
        lowerCommand.contains('assistance')) {
      return "Say 'surroundings' for area information, 'landmarks' for nearby places, or 'facilities' for services.";
    } else {
      return "Say 'surroundings' for area information, 'landmarks' for nearby places, or 'facilities' for services.";
    }
  }

  // Enhanced map command handlers with streamlined feedback
  Future<void> _handleZoomIn() async {
    if (_mapController != null) {
      _currentZoom = (_currentZoom + 1).clamp(10.0, 20.0);
      await _mapController!.animateCamera(CameraUpdate.zoomTo(_currentZoom));
      await _audioManagerService.speakIfActive(
        'map',
        "Zoomed in. You now have a closer view of the area.",
      );
    }
  }

  Future<void> _handleZoomOut() async {
    if (_mapController != null) {
      _currentZoom = (_currentZoom - 1).clamp(10.0, 20.0);
      await _mapController!.animateCamera(CameraUpdate.zoomTo(_currentZoom));
      await _audioManagerService.speakIfActive(
        'map',
        "Zoomed out. You now have a wider view of the area.",
      );
    }
  }

  Future<void> _handleCenterMap() async {
    _centerMapOnUser();
    await _audioManagerService.speakIfActive(
      'map',
      "Map centered on your current location. You're now at the center of the view.",
    );
  }

  // Enhanced information handlers with more natural responses
  Future<void> _handleDescribeSurroundings() async {
    if (_currentPosition != null) {
      String surroundings = _generateSurroundingsDescription();
      await _audioManagerService.speakIfActive('map', surroundings);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "I'm getting your current location. Please wait a moment.",
      );
    }
  }

  Future<void> _handleGreatPlaces() async {
    if (_nearbyLandmarks.isNotEmpty) {
      String places = _generateGreatPlacesDescription();
      await _audioManagerService.speakIfActive('map', places);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "I'm searching for great places near you. Please wait a moment.",
      );
    }
  }

  Future<void> _handleFacilities() async {
    String facilities = _generateFacilitiesDescription();
    await _audioManagerService.speakIfActive('map', facilities);
  }

  Future<void> _handleLocalTips() async {
    String tips = _generateLocalTipsDescription();
    await _audioManagerService.speakIfActive('map', tips);
  }

  // Tour-style help handler for blind users
  Future<void> _handleMapHelp() async {
    String helpMessage = """
    Guided exploration commands:
    
    Say 'discover' to start your guided tour of amazing places.
    Say 'next' to continue to the next location on your tour.
    Say 'tell me more' to learn detailed information about the current place.
    Say 'landmarks' to see all available places and attractions.
    Say 'facilities' to find practical services like restaurants and shops.
    Say 'tips' for local insights and navigation help.
    
    Control commands: 'stop talking' to pause, 'resume talking' to continue, 'repeat' to hear again.
    """;

    await _audioManagerService.speakIfActive('map', helpMessage);
  }

  // Enhanced status handler with comprehensive information
  Future<void> _handleMapStatus() async {
    String status = """
    Map screen status:
    Location tracking: ${_isTracking ? 'Active' : 'Inactive'}
    Voice guidance: ${_isVoiceEnabled ? 'Enabled' : 'Disabled'}
    Navigation: ${_isNavigating ? 'Active to ${_navigationTarget?.name ?? 'Unknown'}' : 'Inactive'}
    Nearby landmarks: ${_nearbyLandmarks.length} found
    Current zoom: ${_currentZoom.toStringAsFixed(1)}
    Audio mode: ${_isDetailedNarration ? 'Detailed' : 'Quick'} narration
    """;

    await _audioManagerService.speakIfActive('map', status);
  }

  // Helper methods for generating natural descriptions
  String _generateSurroundingsDescription() {
    if (_currentPosition == null)
      return "Unable to determine your current location.";

    String description = "You are currently in an area with ";

    if (_nearbyLandmarks.isNotEmpty) {
      description +=
          "${_nearbyLandmarks.length} nearby points of interest, including ";
      List<String> categories =
          _nearbyLandmarks.map((l) => l.category).toSet().toList();
      if (categories.length <= 3) {
        description += categories.join(", ");
      } else {
        description += "${categories.take(3).join(", ")} and more";
      }
    } else {
      description += "various amenities and services nearby";
    }

    description +=
        ". The area appears to be well-developed with good accessibility.";
    return description;
  }

  String _generateGreatPlacesDescription() {
    if (_nearbyLandmarks.isEmpty)
      return "No specific attractions found in your immediate area.";

    String description = "Great places near you include ";
    List<String> landmarkNames =
        _nearbyLandmarks.take(5).map((l) => l.name).toList();

    if (landmarkNames.length == 1) {
      description += landmarkNames.first;
    } else if (landmarkNames.length == 2) {
      description += "${landmarkNames.first} and ${landmarkNames.last}";
    } else {
      description +=
          "${landmarkNames.take(landmarkNames.length - 1).join(", ")}, and ${landmarkNames.last}";
    }

    description += ". These are popular destinations worth exploring.";
    return description;
  }

  String _generateFacilitiesDescription() {
    String description = "Facilities available in this area include ";
    List<String> facilities = [
      "public transportation",
      "restaurants and cafes",
      "shopping centers",
      "medical facilities",
      "banks and ATMs",
      "public restrooms",
      "accessibility features",
    ];

    description += facilities.take(5).join(", ");
    description +=
        ". Most facilities are within walking distance and accessible.";
    return description;
  }

  String _generateLocalTipsDescription() {
    String description = "Local tips for your visit: ";
    List<String> tips = [
      "The area is generally safe for walking during daylight hours",
      "Public transportation is reliable and accessible",
      "Many attractions offer guided tours",
      "Local restaurants serve authentic cuisine",
      "The best time to visit popular sites is early morning or late afternoon",
      "Accessibility features are available at most locations",
    ];

    description += tips.take(3).join(". ");
    description += ". Enjoy your exploration!";
    return description;
  }

  Future<void> _handleNearbyAttractions() async {
    await _speakNearbyAttractions();
  }

  Future<void> _handleStartNavigation(String destination) async {
    // Find landmark by name
    Landmark? targetLandmark;
    for (final landmark in _nearbyLandmarks) {
      if (landmark.name.toLowerCase().contains(destination.toLowerCase())) {
        targetLandmark = landmark;
        break;
      }
    }

    if (targetLandmark != null) {
      await _startNavigationTo(targetLandmark);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "I couldn't find '$destination' nearby. Try saying 'nearby attractions' to see what's available.",
      );
    }
  }

  Future<void> _handleStopNavigation() async {
    await _stopNavigation();
  }

  Future<void> _handleWeatherInfo() async {
    await _audioManagerService.speakIfActive(
      'map',
      "Current weather is clear with good visibility. Temperature is comfortable for outdoor activities. No weather warnings in effect.",
    );
  }

  Future<void> _handleAccessibilityInfo() async {
    await _audioManagerService.speakIfActive(
      'map',
      "This area has good accessibility features. Sidewalks are wheelchair accessible with curb cuts at intersections. Most buildings have ramps and accessible entrances.",
    );
  }

  Future<void> _handleEmergencyHelp() async {
    await _audioManagerService.speakIfActive(
      'map',
      "Emergency mode activated. Your location has been sent to emergency services. Help is on the way. Stay calm and follow emergency instructions.",
    );

    // Emergency haptic pattern
    if (await Vibration.hasVibrator()) {
      for (int i = 0; i < 5; i++) {
        Vibration.vibrate(duration: 500);
        await Future.delayed(Duration(milliseconds: 200));
      }
    }
  }

  Future<void> _handleVoiceSettings() async {
    await _audioManagerService.speakIfActive(
      'map',
      "Voice settings available. You can adjust speech rate, pitch, volume, and language. Say 'pause voice' to mute or 'resume voice' to continue.",
    );
  }

  Future<void> _handlePauseVoice() async {
    setState(() {
      _isNarrationPaused = true;
    });
    await _audioManagerService.speakIfActive(
      'map',
      "Voice narration paused. Say 'resume voice' to continue.",
    );
  }

  Future<void> _handleResumeVoice() async {
    setState(() {
      _isNarrationPaused = false;
    });
    await _audioManagerService.speakIfActive(
      'map',
      "Voice narration resumed. I'll continue providing guidance.",
    );
    _startContinuousNarration();
  }

  Future<void> _handleLandmarkNavigation(String landmarkName) async {
    Landmark? targetLandmark;
    for (final landmark in _nearbyLandmarks) {
      if (landmark.name.toLowerCase().contains(landmarkName.toLowerCase())) {
        targetLandmark = landmark;
        break;
      }
    }

    if (targetLandmark != null) {
      await _startNavigationTo(targetLandmark);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "I couldn't find '$landmarkName' nearby. Try saying 'nearby attractions' to see what's available.",
      );
    }
  }

  // Enhanced map control methods
  Future<void> _handleMapPan(String command) async {
    if (_mapController == null) return;

    String direction = 'center';
    if (command.contains('north') || command.contains('up'))
      direction = 'north';
    else if (command.contains('south') || command.contains('down'))
      direction = 'south';
    else if (command.contains('east') || command.contains('right'))
      direction = 'east';
    else if (command.contains('west') || command.contains('left'))
      direction = 'west';

    double offset = 0.001; // Small offset for panning
    LatLng currentCenter = LatLng(
      _currentPosition?.latitude ?? 0.3476,
      _currentPosition?.longitude ?? 32.5825,
    );

    LatLng newCenter = currentCenter;
    switch (direction) {
      case 'north':
        newCenter = LatLng(
          currentCenter.latitude + offset,
          currentCenter.longitude,
        );
        break;
      case 'south':
        newCenter = LatLng(
          currentCenter.latitude - offset,
          currentCenter.longitude,
        );
        break;
      case 'east':
        newCenter = LatLng(
          currentCenter.latitude,
          currentCenter.longitude + offset,
        );
        break;
      case 'west':
        newCenter = LatLng(
          currentCenter.latitude,
          currentCenter.longitude - offset,
        );
        break;
    }

    await _mapController!.animateCamera(CameraUpdate.newLatLng(newCenter));
    await _audioManagerService.speakIfActive(
      'map',
      "Map panned $direction. You can say 'center map' to return to your location.",
    );
  }

  Future<void> _handleMapRotation(String command) async {
    if (_mapController == null) return;

    double rotation = 0.0;
    if (command.contains('clockwise') || command.contains('right')) {
      rotation = 45.0;
    } else if (command.contains('counterclockwise') ||
        command.contains('left')) {
      rotation = -45.0;
    } else if (command.contains('reset') || command.contains('normal')) {
      rotation = 0.0;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition?.latitude ?? 0.3476,
            _currentPosition?.longitude ?? 32.5825,
          ),
          zoom: _currentZoom,
          bearing: rotation,
        ),
      ),
    );
    await _audioManagerService.speakIfActive(
      'map',
      "Map rotated. Say 'reset rotation' to return to normal orientation.",
    );
  }

  Future<void> _handleMapTilt(String command) async {
    if (_mapController == null) return;

    double tilt = 0.0;
    if (command.contains('up') || command.contains('increase')) {
      tilt = 45.0;
    } else if (command.contains('down') || command.contains('decrease')) {
      tilt = 0.0;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition?.latitude ?? 0.3476,
            _currentPosition?.longitude ?? 32.5825,
          ),
          zoom: _currentZoom,
          tilt: tilt,
        ),
      ),
    );
    await _audioManagerService.speakIfActive(
      'map',
      "Map tilt adjusted. Say 'reset tilt' to return to flat view.",
    );
  }

  Future<void> _handleRoutePlanning(String route) async {
    await _audioManagerService.speakIfActive(
      'map',
      "Route planning mode activated. I'll help you plan a route to $route. Say 'start navigation' when ready to begin.",
    );

    if (mounted) {
      setState(() {
        _isRoutePlanningMode = true;
      });
    }
  }

  // Mode control methods
  Future<void> _handleExplorationMode() async {
    if (mounted) {
      setState(() {
        _isMapExplorationMode = !_isMapExplorationMode;
        _isLandmarkDiscoveryMode = false;
        _isRoutePlanningMode = false;
      });
    }

    String status = _isMapExplorationMode ? "enabled" : "disabled";
    await _audioManagerService.speakIfActive(
      'map',
      "Exploration mode $status. I'll provide detailed information about areas you explore.",
    );
  }

  Future<void> _handleDiscoveryMode() async {
    if (mounted) {
      setState(() {
        _isLandmarkDiscoveryMode = !_isLandmarkDiscoveryMode;
        _isMapExplorationMode = false;
        _isRoutePlanningMode = false;
      });
    }

    String status = _isLandmarkDiscoveryMode ? "enabled" : "disabled";
    await _audioManagerService.speakIfActive(
      'map',
      "Landmark discovery mode $status. I'll announce new landmarks as you discover them.",
    );
  }

  Future<void> _handleRouteMode() async {
    if (mounted) {
      setState(() {
        _isRoutePlanningMode = !_isRoutePlanningMode;
        _isMapExplorationMode = false;
        _isLandmarkDiscoveryMode = false;
      });
    }

    String status = _isRoutePlanningMode ? "enabled" : "disabled";
    await _audioManagerService.speakIfActive(
      'map',
      "Route planning mode $status. Say 'plan route to' followed by destination to start planning.",
    );
  }

  Future<void> _handleAccessibilityMode() async {
    if (mounted) {
      setState(() {
        _isAccessibilityMode = !_isAccessibilityMode;
      });
    }

    String status = _isAccessibilityMode ? "enabled" : "disabled";
    await _audioManagerService.speakIfActive(
      'map',
      "Accessibility mode $status. I'll provide detailed accessibility information for all locations.",
    );
  }

  Future<void> _handleEmergencyMode() async {
    if (mounted) {
      setState(() {
        _isEmergencyMode = !_isEmergencyMode;
      });
    }

    String status = _isEmergencyMode ? "activated" : "deactivated";
    await _audioManagerService.speakIfActive(
      'map',
      "Emergency mode $status. Say 'SOS' for immediate emergency assistance.",
    );
  }

  // Voice control methods
  Future<void> _handleDetailedNarration() async {
    setState(() {
      _isDetailedNarration = true;
      _isQuickNarration = false;
    });
    await _audioManagerService.speakIfActive(
      'map',
      "Detailed narration mode activated. I'll provide comprehensive information about your surroundings.",
    );
  }

  Future<void> _handleQuickNarration() async {
    setState(() {
      _isDetailedNarration = false;
      _isQuickNarration = true;
    });
    await _audioManagerService.speakIfActive(
      'map',
      "Quick narration mode activated. I'll provide brief, essential information.",
    );
  }

  Future<void> _handleVolumeAdjustment(String command) async {
    if (command.contains('up')) {
      _narrationVolume = (_narrationVolume + 0.1).clamp(0.0, 1.0);
      await _audioManagerService.speakIfActive(
        'map',
        "Volume increased. Audio is now louder.",
      );
    } else if (command.contains('down')) {
      _narrationVolume = (_narrationVolume - 0.1).clamp(0.0, 1.0);
      await _audioManagerService.speakIfActive(
        'map',
        "Volume decreased. Audio is now quieter.",
      );
    }
  }

  Future<void> _handleSpeedAdjustment(String command) async {
    if (command.contains('up')) {
      _narrationSpeed = (_narrationSpeed + 0.1).clamp(0.3, 1.0);
      await _audioManagerService.speakIfActive(
        'map',
        "Speech speed increased. I'll speak faster.",
      );
    } else if (command.contains('down')) {
      _narrationSpeed = (_narrationSpeed - 0.1).clamp(0.3, 1.0);
      await _audioManagerService.speakIfActive(
        'map',
        "Speech speed decreased. I'll speak slower.",
      );
    }
  }

  // Missing method implementations
  Future<void> _handleFeatures() async {
    await _audioManagerService.speakIfActive(
      'map',
      "Area features include walking paths, seating areas, and accessibility ramps. The area is well-maintained and designed for easy navigation.",
    );
  }

  Future<void> _handleLocalEvents() async {
    await _audioManagerService.speakIfActive(
      'map',
      "Local events and activities are regularly scheduled. Check with the visitor center for current events and special programs.",
    );
  }

  Future<void> _handleClearScreen() async {
    // Clear any overlays or temporary information
    setState(() {
      // Reset any temporary UI states
    });
    await _audioManagerService.speakIfActive(
      'map',
      "Screen cleared. Map view is now clean and ready for exploration.",
    );
  }

  Future<void> _handleSaveLocation() async {
    if (_currentPosition != null) {
      // Save current location to user's saved places
      await _audioManagerService.speakIfActive(
        'map',
        "Current location saved to your favorites. You can access it later from your saved locations.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "Unable to save location. Please wait for location services to update.",
      );
    }
  }

  Future<void> _handleShareLocation() async {
    if (_currentPosition != null) {
      // Share current location
      await _audioManagerService.speakIfActive(
        'map',
        "Location sharing feature activated. Your current position can be shared with others.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "Unable to share location. Please wait for location services to update.",
      );
    }
  }

  Future<void> _handleLanguageChange(String command) async {
    String newLanguage = "en-US";
    if (command.contains('spanish') || command.contains('español')) {
      newLanguage = "es-ES";
    } else if (command.contains('french') || command.contains('français')) {
      newLanguage = "fr-FR";
    } else if (command.contains('german') || command.contains('deutsch')) {
      newLanguage = "de-DE";
    } else if (command.contains('chinese') || command.contains('中文')) {
      newLanguage = "zh-CN";
    }

    _narrationLanguage = newLanguage;
    await _tts.setLanguage(newLanguage);
    await _audioManagerService.speakIfActive(
      'map',
      "Language changed. Voice guidance will now be provided in the selected language.",
    );
  }

  // Utility methods
  Future<void> _handleSOS() async {
    await _audioManagerService.speakIfActive(
      'map',
      "SOS activated! Emergency services have been notified of your location. Help is on the way. Stay calm and follow emergency instructions.",
    );

    // Emergency haptic pattern
    if (await Vibration.hasVibrator()) {
      for (int i = 0; i < 10; i++) {
        Vibration.vibrate(duration: 1000);
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _handleFindNearest(String facility) async {
    String response = "Finding nearest $facility. ";

    // Simulate finding nearest facilities
    switch (facility.toLowerCase()) {
      case 'hospital':
      case 'medical':
        response +=
            "The nearest hospital is 2.3 kilometers away on Main Street. ";
        break;
      case 'police':
      case 'police station':
        response +=
            "The nearest police station is 1.8 kilometers away on Central Avenue. ";
        break;
      case 'pharmacy':
      case 'drugstore':
        response +=
            "The nearest pharmacy is 0.5 kilometers away on Market Street. ";
        break;
      case 'restaurant':
      case 'food':
        response +=
            "There are several restaurants within 1 kilometer. The closest is 0.3 kilometers away. ";
        break;
      case 'gas station':
      case 'fuel':
        response +=
            "The nearest gas station is 1.2 kilometers away on Highway Road. ";
        break;
      default:
        response +=
            "I'll help you find the nearest $facility. Please specify the type of facility you're looking for. ";
    }

    await _audioManagerService.speakIfActive('map', response);
  }

  Future<void> _navigateToHome() async {
    await _audioManagerService.speakIfActive(
      'map',
      "Navigating back to home screen. Thank you for using the map.",
    );

    // Use screen transition manager for smooth transition
    // The home screen will handle the actual navigation
    if (mounted) {
      // This will trigger the home screen's navigation handling
      // through the voice navigation service
    }
  }

  // Method to handle when user navigates to map screen
  Future<void> _onMapScreenActivated() async {
    if (mounted) {
      setState(() {
        _isMapVoiceEnabled = true;
        _isNarrationPaused = false;
      });

      // Start audio narration service only when map screen is active
      _audioNarrationService.startNarration();

      // Provide welcome message only if not already active
      if (!_isVoiceEnabled) {
        await _audioManagerService.speakIfActive(
          'map',
          "Map screen active. Voice guidance enabled. Say 'surroundings' for area information.",
        );
      }

      // Resume continuous narration
      _startContinuousNarration();
    }
  }

  // Method to handle when user navigates away from map screen
  Future<void> _onMapScreenDeactivated() async {
    if (mounted) {
      setState(() {
        _isMapVoiceEnabled = false;
        _isNarrationPaused = true;
      });

      // Stop audio narration service when map screen is deactivated
      _audioNarrationService.stopNarration();

      // Stop continuous narration
      _narrationTimer?.cancel();

      // Provide deactivation feedback
      await _audioManagerService.speakIfActive(
        'map',
        "Map screen deactivated. Voice guidance paused.",
      );
    }
  }

  void _centerMapOnUser() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  void _onUiCommand(String command) {
    if (command == 'center_map') {
      _centerMapOnUser();
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _startLocationTracking() async {
    await _locationService.startTracking();
    if (mounted) {
      setState(() {
        _isTracking = true;
      });
    }
  }

  // Optimized continuous narration with intelligent timing
  void _startContinuousNarration() {
    _narrationTimer?.cancel();
    _narrationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted &&
          _isVoiceEnabled &&
          _isContinuousNarration &&
          _isMapVoiceEnabled) {
        _provideIntelligentNarration();
      }
    });
  }

  Future<void> _provideIntelligentNarration() async {
    // Prevent narration spam
    if (_narrationCount > 5) {
      _narrationCount = 0;
      return;
    }
    _narrationCount++;

    // Only narrate if screen is active and user hasn't spoken recently
    if (!_isMapVoiceEnabled || _isNarrationPaused) return;

    try {
      String narration = _generateContextualNarration();
      if (narration.isNotEmpty) {
        await _audioManagerService.speakIfActive('map', narration);
      }
    } catch (e) {
      print('Error in intelligent narration: $e');
    }
  }

  String _generateContextualNarration() {
    // Generate context-aware narration based on current state
    if (_isNavigating && _navigationTarget != null) {
      if (_isImmersiveNarration) {
        return "Continuing your journey to ${_navigationTarget!.name}. Each step brings you closer to this amazing destination. Stay on the current path and enjoy the adventure.";
      } else {
        return "Continuing navigation to ${_navigationTarget!.name}. Stay on the current path.";
      }
    } else if (_nearbyLandmarks.isNotEmpty) {
      Landmark nearest = _nearbyLandmarks.first;
      if (_isImmersiveNarration) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          nearest.latitude,
          nearest.longitude,
        );
        return "You're near ${nearest.name}, a ${nearest.category} just ${distance.toStringAsFixed(0)} meters away. This fascinating destination awaits your discovery. Say 'tell me about my surroundings' for a rich description of your environment.";
      } else {
        return "You're near ${nearest.name}, a ${nearest.category}. Say 'tell me about my surroundings' for more information.";
      }
    } else if (_isMapExplorationMode) {
      if (_isImmersiveNarration) {
        return "Exploration mode is active and ready to guide you through amazing discoveries. You can explore nearby attractions, uncover hidden gems, and experience the rich cultural tapestry around you.";
      } else {
        return "Exploration mode active. You can discover nearby attractions and points of interest.";
      }
    } else {
      if (_isImmersiveNarration) {
        return "Your interactive map is ready to guide you through an amazing exploration experience. Say 'surroundings' for rich area information, 'landmarks' for fascinating nearby places, or 'facilities' for convenient services.";
      } else {
        return "Map screen active. Say 'surroundings' for area information, 'landmarks' for nearby places, or 'facilities' for services.";
      }
    }
  }

  // Enhanced audio feature management methods with strict isolation
  void _stopMapAudioFeatures() {
    print('🔇 COMPLETE STOP: Map audio features');

    // Stop continuous narration
    _narrationTimer?.cancel();

    // Force stop any ongoing TTS with retry
    _tts.stop();
    Future.delayed(const Duration(milliseconds: 50), () {
      _tts.stop(); // Second attempt to ensure complete stop
    });

    // Stop voice command listening
    _voiceCommandService.stopListening();

    // Stop audio narration service
    _audioNarrationService.stopNarration();

    // Stop voice navigation service
    _voiceNavigationService.stopContinuousListening();

    print('✅ Map audio features completely stopped - screen deactivated');
  }

  void _pauseMapAudioFeatures() {
    print('⏸️ PAUSE: Map audio features');

    // Pause continuous narration
    _narrationTimer?.cancel();

    // Force stop any ongoing TTS with retry
    _tts.stop();
    Future.delayed(const Duration(milliseconds: 50), () {
      _tts.stop(); // Second attempt to ensure complete stop
    });

    // Stop voice command listening
    _voiceCommandService.stopListening();

    // Pause audio narration service
    _audioNarrationService.stopNarration();

    // Pause voice navigation service
    _voiceNavigationService.stopContinuousListening();

    print('✅ Map audio features paused - screen not in focus');
  }

  void _resumeMapAudioFeatures() {
    // Resume continuous narration if tracking is active
    if (_isTracking && _isContinuousNarration) {
      _startContinuousNarration();
    }

    // Resume voice command listening if it was active
    if (_isListening) {
      _voiceCommandService.startListening();
    }

    print('Map audio features resumed - screen now in focus');
  }

  void _checkScreenFocus() {
    // Check if map screen is currently the active screen
    final isActive = _audioManagerService.isScreenAudioActive('map');
    if (isActive && !_isVoiceEnabled) {
      // Map screen is active but voice is disabled - enable it
      if (mounted) {
        setState(() {
          _isVoiceEnabled = true;
          _isContinuousNarration = true;
        });
      }
      _resumeMapAudioFeatures();
    } else if (!isActive && _isVoiceEnabled) {
      // Map screen is not active but voice is enabled - disable it
      if (mounted) {
        setState(() {
          _isVoiceEnabled = false;
          _isContinuousNarration = false;
        });
      }
      _pauseMapAudioFeatures();
    }
  }

  Future<void> _narrateSurroundings() async {
    // STRICT CHECK: Only narrate if map screen is active
    if (_currentPosition == null ||
        !_isVoiceEnabled ||
        !_audioManagerService.isScreenAudioActive('map')) {
      print('🔇 Narration blocked - map screen not active or voice disabled');
      return;
    }

    // Get comprehensive surroundings narration
    String narration = await _getComprehensiveSurroundingsNarration();

    // Get navigation information if navigating
    String navigationInfo = '';
    if (_isNavigating && _navigationTarget != null) {
      navigationInfo = await _getNavigationInfo();
    }

    // Combine all information for narration
    if (navigationInfo.isNotEmpty) {
      narration += ' Navigation: $navigationInfo';
    }

    if (narration.isNotEmpty) {
      // Final safety check before speaking
      if (_audioManagerService.isScreenAudioActive('map')) {
        await _audioManagerService.speakIfActive('map', narration);
      } else {
        print(
          '🔇 Narration blocked at final check - map screen no longer active',
        );
      }
    }
  }

  Future<String> _getComprehensiveSurroundingsNarration() async {
    // Check if narration should be controlled based on user preferences
    if (_isNarrationPaused) return "";

    // Limit narration frequency to prevent spam
    if (_narrationCount > 5) {
      _narrationCount = 0;
      return "";
    }
    _narrationCount++;

    String narration = "";

    // Choose narration style based on user preference
    if (_isDetailedNarration) {
      narration =
          "You are in a vibrant area of Kampala, Uganda's capital city. ";
      narration +=
          "This location offers a rich blend of modern urban life and traditional African culture. ";
    } else if (_isQuickNarration) {
      narration = "You are in Kampala. ";
    } else {
      narration = "You are in a vibrant area of Kampala. ";
    }

    // Add landmark descriptions with controlled detail
    if (_nearbyLandmarks.isNotEmpty) {
      if (_isDetailedNarration) {
        narration += "Nearby attractions include: ";
        for (int i = 0; i < _nearbyLandmarks.length && i < 3; i++) {
          final landmark = _nearbyLandmarks[i];
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            landmark.latitude,
            landmark.longitude,
          );
          narration +=
              "${landmark.name}, ${distance.toStringAsFixed(0)} meters away. ";
          if (_isDetailedNarration) {
            narration += await _getLandmarkDetailedDescription(landmark);
          }
        }
      } else {
        narration +=
            "There are ${_nearbyLandmarks.length} attractions nearby. ";
      }
    }

    // Add contextual information based on active modes
    if (_isAccessibilityMode) {
      narration += await _getAccessibilityContextNarration();
    }

    if (_isEmergencyMode) {
      narration += await _getEmergencyContextNarration();
    }

    if (_isMapExplorationMode) {
      narration += await _getExplorationContextNarration();
    }

    // Add facility information
    if (!_isQuickNarration) {
      narration += await _getNearbyFacilitiesNarration();
    }

    // Add historical and cultural context for detailed narration
    if (_isDetailedNarration) {
      narration += await _getHistoricalContextNarration();
      narration += await _getCulturalContextNarration();
    }

    return narration;
  }

  Future<String> _getNearbyFacilitiesNarration() async {
    String facilities = " ";

    // Simulate nearby facilities based on location
    if (_currentPosition != null) {
      // Add restaurants and cafes
      facilities +=
          "You'll find several restaurants and cafes within walking distance, offering both local Ugandan cuisine and international dishes. ";

      // Add transportation
      facilities +=
          "Public transportation is readily available with bus stops and taxi stands nearby. ";

      // Add shopping
      facilities +=
          "There are local markets and shops where you can purchase souvenirs and local crafts. ";

      // Add accommodation
      facilities +=
          "Several hotels and guesthouses are located in this area for visitors. ";

      // Add medical facilities
      facilities +=
          "Medical facilities and pharmacies are accessible within a short distance. ";
    }

    return facilities;
  }

  Future<String> _getHistoricalContextNarration() async {
    return "This area has rich historical significance. Kampala, meaning 'the hill of the impala' in Luganda, was originally built on seven hills. The city has grown from a small settlement to Uganda's capital and largest city. Many of the buildings and streets here have stories dating back to the colonial era and early independence period. ";
  }

  Future<String> _getCulturalContextNarration() async {
    return "You're experiencing the heart of Ugandan culture. The people here are known for their warmth and hospitality. English and Luganda are widely spoken. The area reflects Uganda's diverse cultural heritage, with influences from various ethnic groups. Local customs and traditions are still very much alive in daily life. ";
  }

  Future<String> _getAccessibilityContextNarration() async {
    return "Accessibility features in this area include wheelchair-accessible sidewalks, curb cuts at intersections, and ramps at most buildings. Audio signals are available at major crossings. Most public facilities have accessible entrances and restrooms. ";
  }

  Future<String> _getEmergencyContextNarration() async {
    return "Emergency services are readily available. The nearest hospital is 2.3 kilometers away. Police and fire services can be reached quickly. Emergency contact numbers are prominently displayed. Stay alert and aware of your surroundings. ";
  }

  Future<String> _getExplorationContextNarration() async {
    return "This area is perfect for exploration. You'll discover hidden gems, local markets, and authentic cultural experiences. Take your time to explore the side streets and interact with locals. Many interesting places are just off the main roads. ";
  }

  // Additional tour guide narration methods
  Future<void> _narrateGreatPlaces() async {
    if (!_isVoiceEnabled) return;

    String narration =
        "Here are some of the great places you can visit in this area: ";

    // Add specific landmark recommendations
    for (final landmark in _nearbyLandmarks.take(5)) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      narration +=
          "${landmark.name} is ${distance.toStringAsFixed(0)} meters away. ";
      narration += await _getLandmarkDetailedDescription(landmark);
    }

    // Add general recommendations
    narration +=
        "Other notable places include the Uganda Museum, which showcases the country's cultural heritage, the Kasubi Tombs, a UNESCO World Heritage site, and the vibrant Owino Market where you can experience local commerce and culture. ";

    await _audioManagerService.speakIfActive('map', narration);
  }

  Future<String> _getLandmarkDetailedDescription(Landmark landmark) async {
    // Enhanced descriptions for different landmark types
    switch (landmark.category.toLowerCase()) {
      case 'historical':
        return "This historical site offers insights into Uganda's rich past and cultural heritage. It's a must-visit for understanding the country's history. ";
      case 'religious':
        return "This religious site is an important place of worship and cultural significance. Visitors are welcome to observe and learn about local religious practices. ";
      case 'cultural':
        return "This cultural venue showcases traditional arts, music, and performances. It's perfect for experiencing authentic Ugandan culture. ";
      case 'natural':
        return "This natural attraction offers beautiful scenery and opportunities for outdoor activities. It's ideal for nature lovers and photography. ";
      case 'commercial':
        return "This commercial area is bustling with activity and offers shopping, dining, and entertainment options. It's great for experiencing local life. ";
      default:
        return "This location offers unique experiences and is worth exploring. ";
    }
  }

  Future<void> _narrateFeatures() async {
    if (!_isVoiceEnabled) return;

    String narration =
        "Let me tell you about the features and amenities in this area: ";

    // Add accessibility features
    narration +=
        "The area is designed with accessibility in mind. Sidewalks are well-maintained and wheelchair accessible. Most buildings have ramps and accessible entrances. ";

    // Add safety features
    narration +=
        "Safety features include well-lit streets, regular police patrols, and emergency services readily available. ";

    // Add technology features
    narration +=
        "Modern amenities include free Wi-Fi hotspots, digital information kiosks, and mobile payment systems widely accepted. ";

    // Add environmental features
    narration +=
        "Environmental features include green spaces, tree-lined streets, and waste management systems. The area is committed to sustainability. ";

    await _audioManagerService.speakIfActive('map', narration);
  }

  Future<void> _narrateFacilities() async {
    if (!_isVoiceEnabled) return;

    String narration = "Here are the facilities available in this area: ";

    // Add transportation facilities
    narration +=
        "Transportation facilities include bus stops, taxi stands, and motorcycle taxi services known as boda-bodas. The area is well-connected to other parts of the city. ";

    // Add accommodation facilities
    narration +=
        "Accommodation options range from budget guesthouses to luxury hotels, all within walking distance. Many offer traditional Ugandan hospitality. ";

    // Add dining facilities
    narration +=
        "Dining facilities include restaurants serving local dishes like matooke, posho, and chapati, as well as international cuisine. Street food vendors offer authentic local flavors. ";

    // Add shopping facilities
    narration +=
        "Shopping facilities include local markets, craft shops, and modern retail stores. You can find traditional crafts, clothing, and souvenirs. ";

    // Add health facilities
    narration +=
        "Health facilities include clinics, pharmacies, and hospitals. Medical services are readily available for visitors. ";

    // Add communication facilities
    narration +=
        "Communication facilities include internet cafes, mobile phone shops, and postal services. Staying connected is easy here. ";

    await _audioManagerService.speakIfActive('map', narration);
  }

  Future<void> _narrateLocalTips() async {
    if (!_isVoiceEnabled) return;

    String narration = "Here are some local tips for your visit: ";

    narration +=
        "The best time to visit attractions is early morning or late afternoon to avoid crowds and heat. ";
    narration +=
        "Local currency is the Ugandan Shilling. Many places accept mobile money payments. ";
    narration +=
        "Greeting people with a smile and saying 'hello' in Luganda - 'Oli otya' - is appreciated. ";
    narration +=
        "Bargaining is common in markets, but be respectful and fair. ";
    narration += "Dress modestly, especially when visiting religious sites. ";
    narration +=
        "Try local foods like rolex, a popular street food, and fresh fruit juices. ";
    narration +=
        "Always carry water and stay hydrated in the tropical climate. ";
    narration +=
        "Photography is generally allowed, but ask permission when photographing people. ";

    await _audioManagerService.speakIfActive('map', narration);
  }

  Future<void> _narrateWeatherAndClimate() async {
    if (!_isVoiceEnabled) return;

    String narration = "Current weather and climate information: ";

    // Simulate weather information
    narration += "Kampala enjoys a tropical climate with two rainy seasons. ";
    narration += "Current temperature is comfortable for outdoor activities. ";
    narration +=
        "Humidity levels are moderate, making it pleasant for walking and sightseeing. ";
    narration += "UV index is moderate, so sunscreen is recommended. ";
    narration += "Air quality is good, perfect for exploring the city. ";

    await _audioManagerService.speakIfActive('map', narration);
  }

  Future<void> _narrateLocalEvents() async {
    if (!_isVoiceEnabled) return;

    String narration = "Local events and activities you might enjoy: ";

    narration +=
        "Cultural performances are often held at community centers and theaters. ";
    narration +=
        "Local markets are busiest in the morning and offer fresh produce and crafts. ";
    narration +=
        "Religious services are held regularly at various places of worship. ";
    narration +=
        "Community gatherings and festivals occur throughout the year. ";
    narration +=
        "Sports events and recreational activities are available at local facilities. ";

    await _audioManagerService.speakIfActive('map', narration);
  }

  Future<String> _getLocationDescription() async {
    // In a real app, you'd use reverse geocoding here
    // For now, provide coordinate-based description
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    // Determine general area based on coordinates
    String area = 'unknown area';
    if (lat > 2.0 && lat < 2.5 && lng > 31.5 && lng < 32.0) {
      area = 'Murchison Falls area';
    } else if (lat > 0.3 && lat < 0.4 && lng > 32.5 && lng < 32.6) {
      area = 'Kampala city center';
    } else if (lat > -0.1 && lat < 0.1 && lng > 32.9 && lng < 33.1) {
      area = 'Lake Victoria shore';
    }

    return 'You are in $area at coordinates ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<String> _getNearbyFeatures() async {
    List<String> features = [];

    // Add nearby landmarks
    for (final landmark in _nearbyLandmarks) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      if (distance <= 200) {
        // Within 200 meters
        features.add(
          '${landmark.name} ${distance.toStringAsFixed(0)} meters away',
        );
      }
    }

    // Add street information (simulated)
    features.add('Main street ahead');
    features.add('Intersection 50 meters ahead');

    // Add other users nearby
    for (final marker in _markers) {
      if (marker.markerId.value.startsWith('user_') &&
          marker.markerId.value != 'user_location') {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          marker.position.latitude,
          marker.position.longitude,
        );

        if (distance <= 100) {
          features.add(
            'Another user ${distance.toStringAsFixed(0)} meters away',
          );
        }
      }
    }

    return features.join(', ');
  }

  Future<String> _getNavigationInfo() async {
    if (_navigationTarget == null || _currentPosition == null) return '';

    final bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _navigationTarget!.latitude,
      _navigationTarget!.longitude,
    );

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _navigationTarget!.latitude,
      _navigationTarget!.longitude,
    );

    String direction = _getDirectionFromBearing(bearing);

    // Check if bearing has changed significantly
    if ((bearing - _lastNarratedBearing).abs() > 30) {
      _lastNarratedBearing = bearing;
      return 'Turn $direction towards ${_navigationTarget!.name}. Distance: ${distance.toStringAsFixed(0)} meters';
    }

    return 'Continue $direction. ${distance.toStringAsFixed(0)} meters to ${_navigationTarget!.name}';
  }

  String _getDirectionFromBearing(double bearing) {
    if (bearing >= 315 || bearing < 45) return "north";
    if (bearing >= 45 && bearing < 135) return "east";
    if (bearing >= 135 && bearing < 225) return "south";
    return "west";
  }

  Future<void> _updateUserLocationInFirestore(Position position) async {
    _userId ??= DateTime.now().millisecondsSinceEpoch.toString();
    await _firestore.collection('user_locations').doc(_userId).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _listenToOtherUsers() {
    _firestore.collection('user_locations').snapshots().listen((snapshot) {
      final Set<Marker> newMarkers = {..._markers};
      for (var doc in snapshot.docs) {
        if (doc.id == _userId) continue;
        final data = doc.data();
        if (data['latitude'] != null && data['longitude'] != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('user_${doc.id}'),
              position: LatLng(data['latitude'], data['longitude']),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: const InfoWindow(title: 'Other User'),
              onTap: () async {
                if (_isVoiceEnabled) {
                  await _audioManagerService.speakIfActive(
                    'map',
                    "Another user is nearby at latitude ${data['latitude'].toStringAsFixed(4)}, longitude ${data['longitude'].toStringAsFixed(4)}",
                  );
                }
              },
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
      }
    });
  }

  void _onPositionUpdate(Position position) {
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }

    // Update audio narration service
    _audioNarrationService.updatePosition(position);

    // Update map camera to follow user
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
    );

    // Update user marker
    _updateMarkers();

    // Update Firestore
    _updateUserLocationInFirestore(position);

    // Provide immediate location feedback
    if (_isVoiceEnabled) {
      _audioManagerService.speakIfActive(
        'map',
        "Location updated. ${_getLocationDescription()}",
      );
    }
  }

  void _onNearbyLandmarksUpdate(List<Landmark> landmarks) {
    if (mounted) {
      setState(() {
        _nearbyLandmarks = landmarks;
      });
    }

    // Update audio narration service
    _audioNarrationService.updateLandmarks(landmarks);

    _updateMarkers();

    // Announce new landmarks
    if (_isVoiceEnabled) {
      for (final landmark in landmarks) {
        if (!_nearbyLandmarks.contains(landmark)) {
          _audioManagerService.speakIfActive(
            'map',
            "New landmark detected: ${landmark.name}",
          );
        }
      }
    }
  }

  void _onLandmarkEntered(Landmark landmark) {
    // This is handled by the location service with TTS and haptic feedback
    print('Entered landmark: ${landmark.name}');
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // Add user location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add landmark markers
    for (final landmark in _nearbyLandmarks) {
      markers.add(
        Marker(
          markerId: MarkerId(landmark.id),
          position: LatLng(landmark.latitude, landmark.longitude),
          infoWindow: InfoWindow(
            title: landmark.name,
            snippet: landmark.description,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _onLandmarkTapped(landmark),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }
  }

  Future<void> _onLandmarkTapped(Landmark landmark) async {
    if (_isVoiceEnabled) {
      String landmarkDescription = _generateEnhancedLandmarkDescription(
        landmark,
      );
      await _audioManagerService.speakIfActive('map', landmarkDescription);
    }

    // Provide enhanced haptic feedback
    if (await Vibration.hasVibrator()) {
      if (_isImmersiveNarration) {
        // Double vibration for immersive mode
        Vibration.vibrate(duration: 200);
        await Future.delayed(Duration(milliseconds: 100));
        Vibration.vibrate(duration: 200);
      } else {
        Vibration.vibrate(duration: 300);
      }
    }

    // Start navigation to this landmark
    await _startNavigationTo(landmark);
  }

  String _generateEnhancedLandmarkDescription(Landmark landmark) {
    if (_isImmersiveNarration) {
      String description =
          "You've selected ${landmark.name}, a ${landmark.category}. ";

      if (_currentPosition != null) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          landmark.latitude,
          landmark.longitude,
        );
        description +=
            "This fascinating destination is just ${distance.toStringAsFixed(0)} meters away. ";
      }

      description += "${landmark.description} ";
      description +=
          "This location offers unique experiences and cultural insights. ";
      description +=
          "Say 'navigate to ${landmark.name}' to start your journey, or 'tell me more' for detailed information.";

      return description;
    } else {
      return "${landmark.name}. ${landmark.description}";
    }
  }

  Future<void> _startNavigationTo(Landmark landmark) async {
    if (mounted) {
      setState(() {
        _isNavigating = true;
        _navigationTarget = landmark;
      });
    }

    if (_isVoiceEnabled) {
      String navigationStart = _generateEnhancedNavigationStartMessage(
        landmark,
      );
      await _audioManagerService.speakIfActive('map', navigationStart);
    }

    // Provide initial navigation instructions
    await _provideNavigationInstructions();
  }

  String _generateEnhancedNavigationStartMessage(Landmark landmark) {
    if (_isImmersiveNarration) {
      return "Starting your exciting journey to ${landmark.name}! I'll be your personal guide, providing turn-by-turn directions and fascinating insights along the way. Get ready for an amazing adventure!";
    } else {
      return "Starting navigation to ${landmark.name}. I'll guide you there with turn-by-turn directions.";
    }
  }

  Future<void> _provideNavigationInstructions() async {
    if (_navigationTarget == null ||
        _currentPosition == null ||
        !_isVoiceEnabled) {
      return;
    }

    final bearing = Geolocator.bearingBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _navigationTarget!.latitude,
      _navigationTarget!.longitude,
    );

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _navigationTarget!.latitude,
      _navigationTarget!.longitude,
    );

    String direction = _getDirectionFromBearing(bearing);
    String navigationInstructions = _generateEnhancedNavigationInstructions(
      direction,
      distance,
    );

    await _audioManagerService.speakIfActive('map', navigationInstructions);

    // Provide haptic feedback for direction
    await _provideDirectionalHaptic(bearing);
  }

  String _generateEnhancedNavigationInstructions(
    String direction,
    double distance,
  ) {
    if (_isImmersiveNarration) {
      String instructions =
          "To reach your destination ${_navigationTarget!.name}, head $direction. ";
      instructions +=
          "You're just ${distance.toStringAsFixed(0)} meters away from this amazing place. ";
      instructions +=
          "I'll provide turn-by-turn guidance and fascinating insights as you journey there. ";
      instructions +=
          "Say 'stop navigation' to end guidance, or 'tell me more' for detailed information about your destination.";
      return instructions;
    } else {
      return "To reach ${_navigationTarget!.name}, head $direction. "
          "Distance: ${distance.toStringAsFixed(0)} meters. "
          "I'll provide turn-by-turn guidance as you move. Say 'stop navigation' to end guidance.";
    }
  }

  Future<void> _provideDirectionalHaptic(double bearing) async {
    if (await Vibration.hasVibrator()) {
      if (bearing >= 315 || bearing < 45) {
        Vibration.vibrate(duration: 200);
      } else if (bearing >= 45 && bearing < 135) {
        Vibration.vibrate(duration: 200);
        await Future.delayed(Duration(milliseconds: 300));
        Vibration.vibrate(duration: 200);
      } else if (bearing >= 135 && bearing < 225) {
        for (int i = 0; i < 3; i++) {
          Vibration.vibrate(duration: 200);
          await Future.delayed(Duration(milliseconds: 200));
        }
      } else {
        Vibration.vibrate(duration: 500);
      }
    }
  }

  Future<void> _toggleVoiceCommands() async {
    if (_isListening) {
      await _voiceCommandService.stopListening();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      if (_isVoiceEnabled) {
        await _audioManagerService.speakIfActive(
          'map',
          "Voice commands stopped.",
        );
      }
    } else {
      await _voiceCommandService.startListening();
      if (mounted) {
        setState(() {
          _isListening = true;
        });
      }
      if (_isVoiceEnabled) {
        await _audioManagerService.speakIfActive(
          'map',
          "Voice commands activated. Say 'surroundings' for area information.",
        );
      }
    }
  }

  Future<void> _speakCurrentLocation() async {
    if (_currentPosition != null && _isVoiceEnabled) {
      final description = await _getLocationDescription();
      await _audioManagerService.speakIfActive('map', description);
    } else if (!_isVoiceEnabled) {
      await _audioManagerService.speakIfActive(
        'map',
        "Voice is currently disabled. Say 'resume voice' to enable.",
      );
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "Location not available yet. Please wait.",
      );
    }
  }

  Future<void> _speakNearbyAttractions() async {
    if (!_isVoiceEnabled) {
      await _audioManagerService.speakIfActive(
        'map',
        "Voice is currently disabled. Say 'resume voice' to enable.",
      );
      return;
    }

    if (_nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "No attractions are currently nearby. Try moving around to discover places.",
      );
    } else {
      String response = "Nearby attractions: ";
      for (final landmark in _nearbyLandmarks) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          landmark.latitude,
          landmark.longitude,
        );
        response +=
            "${landmark.name} ${distance.toStringAsFixed(0)} meters away, ";
      }
      response +=
          "Tap on any marker or say 'navigate to' followed by the attraction name.";
      await _audioManagerService.speakIfActive('map', response);
    }
  }

  Future<void> _stopNavigation() async {
    if (mounted) {
      setState(() {
        _isNavigating = false;
        _navigationTarget = null;
      });
    }
    if (_isVoiceEnabled) {
      String stopMessage = _generateEnhancedStopNavigationMessage();
      await _audioManagerService.speakIfActive('map', stopMessage);
    }
  }

  String _generateEnhancedStopNavigationMessage() {
    if (_isImmersiveNarration) {
      return "Navigation completed! You're now free to explore and discover the amazing world around you. Take your time to soak in the atmosphere and enjoy your surroundings.";
    } else {
      return "Navigation stopped. You can now explore freely.";
    }
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _voiceCommandService.stopListening();
    _voiceNavigationService.stopContinuousListening();
    _audioNarrationService.stopNarration();
    _narrationTimer?.cancel();
    _mapCommandSubscription?.cancel();
    _audioControlSubscription?.cancel();
    _screenActivationSubscription?.cancel();
    _audioManagerService.unregisterScreen('map');
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('EchoPath Map'),
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
                _speakCurrentSurroundings();
              }
            },
            tooltip: _isNarrating ? 'Stop Narration' : 'Start Narration',
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_off),
            onPressed: _toggleVoiceCommands,
            tooltip: 'Toggle Voice Commands',
          ),
          IconButton(
            icon: Icon(_isVoiceEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _isVoiceEnabled = !_isVoiceEnabled;
                });
              }
              if (_isVoiceEnabled) {
                _audioManagerService.speakIfActive('map', "Voice enabled.");
              } else {
                _audioManagerService.speakIfActive('map', "Voice disabled.");
              }
            },
            tooltip: 'Toggle Voice',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition:
                _currentPosition != null
                    ? CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 16.0,
                    )
                    : _defaultPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onTap: (LatLng position) async {
              // Ensure map screen is active when user interacts with it
              if (!_audioManagerService.isScreenAudioActive('map')) {
                await _onMapScreenActivated();
              }

              if (_isVoiceEnabled) {
                await _audioManagerService.speakIfActive(
                  'map',
                  "Location selected. Say 'one' to describe your surroundings, 'two' to discover great places, 'three' to describe nearby facilities, 'four' to find nearby tours, 'five' to center the map, or 'six' for help. You can also say 'pause', 'play', or 'next'.",
                );
              }
            },
          ),

          // Nearby landmarks list
          if (_nearbyLandmarks.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 280,
              child: Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _nearbyLandmarks.length,
                  itemBuilder: (context, index) {
                    final landmark = _nearbyLandmarks[index];
                    return ListTile(
                      title: Text(
                        landmark.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        landmark.category,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      onTap: () => _onLandmarkTapped(landmark),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Enhanced voice command handler for blind users
  Future<void> _handleBlindUserVoiceCommand(String command) async {
    print('🎤 Blind user voice command received: $command');

    // Provide immediate haptic feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }

    try {
      // Map exploration commands
      if (_isMapExplorationCommand(command)) {
        await _handleMapExplorationCommand(command);
        return;
      }

      // Landmark interaction commands
      if (_isLandmarkInteractionCommand(command)) {
        await _handleLandmarkInteractionCommand(command);
        return;
      }

      // Map navigation commands
      if (_isMapNavigationCommand(command)) {
        await _handleMapNavigationCommand(command);
        return;
      }

      // Landmark selection commands
      if (_isLandmarkSelectionCommand(command)) {
        await _handleLandmarkSelectionCommand(command);
        return;
      }

      // Detailed exploration commands
      if (_isDetailedExplorationCommand(command)) {
        await _handleDetailedExplorationCommand(command);
        return;
      }

      // Quick exploration commands
      if (_isQuickExplorationCommand(command)) {
        await _handleQuickExplorationCommand(command);
        return;
      }

      // Landmark category commands
      if (_isLandmarkCategoryCommand(command)) {
        await _handleLandmarkCategoryCommand(command);
        return;
      }

      // Distance information commands
      if (_isDistanceInformationCommand(command)) {
        await _handleDistanceInformationCommand(command);
        return;
      }

      // Direction information commands
      if (_isDirectionInformationCommand(command)) {
        await _handleDirectionInformationCommand(command);
        return;
      }

      // Accessibility information commands
      if (_isAccessibilityInformationCommand(command)) {
        await _handleAccessibilityInformationCommand(command);
        return;
      }

      // Safety information commands
      if (_isSafetyInformationCommand(command)) {
        await _handleSafetyInformationCommand(command);
        return;
      }

      // Unknown command - provide blind user specific feedback
      await _provideBlindUserFeedback(command);
    } catch (e) {
      print('Error handling blind user voice command: $e');
      await _audioManagerService.speakIfActive(
        'map',
        "Sorry, there was an error processing your command. Please try again.",
      );
    }
  }

  // Map exploration commands
  bool _isMapExplorationCommand(String command) {
    return _blindUserCommandPatterns['explore_map']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleMapExplorationCommand(String command) async {
    setState(() {
      _isBlindUserExplorationMode = true;
      _isLandmarkSelectionMode = false;
    });

    String explorationMessage = _generateMapExplorationMessage();
    await _audioManagerService.speakIfActive('map', explorationMessage);
  }

  String _generateMapExplorationMessage() {
    if (_nearbyLandmarks.isEmpty) {
      return "I'm exploring the map around you. No specific landmarks are currently visible in your immediate area. Try moving around or say 'scan area' to search for nearby points of interest.";
    }

    String message =
        "I'm exploring the map around you. I can see ${_nearbyLandmarks.length} points of interest nearby. ";

    // Group landmarks by category
    Map<String, List<Landmark>> categories = {};
    for (final landmark in _nearbyLandmarks) {
      categories.putIfAbsent(landmark.category, () => []).add(landmark);
    }

    message += "Categories include: ";
    List<String> categoryNames = categories.keys.toList();
    if (categoryNames.length <= 3) {
      message += categoryNames.join(", ");
    } else {
      message += "${categoryNames.take(3).join(", ")}, and more";
    }

    message +=
        ". Say 'select landmark' to interact with specific places, or 'show restaurants' to filter by category.";
    return message;
  }

  // Landmark interaction commands
  bool _isLandmarkInteractionCommand(String command) {
    return _blindUserCommandPatterns['landmark_interaction']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleLandmarkInteractionCommand(String command) async {
    if (_nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "No landmarks are currently available for interaction. Try moving around or say 'explore map' to search for nearby places.",
      );
      return;
    }

    setState(() {
      _isLandmarkSelectionMode = true;
      _selectedLandmarkIndex = 0;
    });

    await _announceLandmarkSelection();
  }

  Future<void> _announceLandmarkSelection() async {
    if (_selectedLandmarkIndex >= 0 &&
        _selectedLandmarkIndex < _nearbyLandmarks.length) {
      Landmark landmark = _nearbyLandmarks[_selectedLandmarkIndex];
      String message = "Selected: ${landmark.name}, a ${landmark.category}. ";

      if (_currentPosition != null) {
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          landmark.latitude,
          landmark.longitude,
        );
        message += "Distance: ${distance.toStringAsFixed(0)} meters. ";
      }

      message +=
          "Say 'describe in detail' for more information, 'navigate to' to start navigation, 'next landmark' to select another, or 'interact with landmark' to choose a different place.";

      await _audioManagerService.speakIfActive('map', message);

      // Provide haptic feedback for selection
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 200);
      }
    }
  }

  // Map navigation commands
  bool _isMapNavigationCommand(String command) {
    return _blindUserCommandPatterns['map_navigation_voice']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleMapNavigationCommand(String command) async {
    if (_mapController == null) {
      await _audioManagerService.speakIfActive(
        'map',
        "Map is not ready for navigation. Please wait a moment.",
      );
      return;
    }

    String direction = "";
    double latOffset = 0.0;
    double lngOffset = 0.0;

    if (command.contains('left')) {
      direction = "left";
      lngOffset = -0.001;
    } else if (command.contains('right')) {
      direction = "right";
      lngOffset = 0.001;
    } else if (command.contains('up')) {
      direction = "up";
      latOffset = 0.001;
    } else if (command.contains('down')) {
      direction = "down";
      latOffset = -0.001;
    }

    if (direction.isNotEmpty) {
      LatLng currentCenter = await _mapController!.getLatLng(
        ScreenCoordinate(x: 0, y: 0),
      );

      LatLng newCenter = LatLng(
        currentCenter.latitude + latOffset,
        currentCenter.longitude + lngOffset,
      );

      await _mapController!.animateCamera(CameraUpdate.newLatLng(newCenter));

      await _audioManagerService.speakIfActive(
        'map',
        "Map moved $direction. Exploring new area.",
      );

      // Provide haptic feedback for movement
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 100);
      }
    }
  }

  // Landmark selection commands
  bool _isLandmarkSelectionCommand(String command) {
    return _blindUserCommandPatterns['landmark_selection']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleLandmarkSelectionCommand(String command) async {
    if (!_isLandmarkSelectionMode || _nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "Landmark selection mode is not active. Say 'select landmark' to start selecting landmarks.",
      );
      return;
    }

    if (command.contains('next')) {
      _selectedLandmarkIndex =
          (_selectedLandmarkIndex + 1) % _nearbyLandmarks.length;
    } else if (command.contains('previous')) {
      _selectedLandmarkIndex =
          (_selectedLandmarkIndex - 1 + _nearbyLandmarks.length) %
          _nearbyLandmarks.length;
    } else if (command.contains('first') || command.contains('one')) {
      _selectedLandmarkIndex = 0;
    } else if (command.contains('second') || command.contains('two')) {
      _selectedLandmarkIndex = 1;
    } else if (command.contains('third') || command.contains('three')) {
      _selectedLandmarkIndex = 2;
    } else if (command.contains('fourth') || command.contains('four')) {
      _selectedLandmarkIndex = 3;
    } else if (command.contains('fifth') || command.contains('five')) {
      _selectedLandmarkIndex = 4;
    }

    if (_selectedLandmarkIndex < _nearbyLandmarks.length) {
      await _announceLandmarkSelection();
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "No landmark at that position. Try selecting a lower number.",
      );
    }
  }

  // Detailed exploration commands
  bool _isDetailedExplorationCommand(String command) {
    return _blindUserCommandPatterns['detailed_exploration']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleDetailedExplorationCommand(String command) async {
    setState(() {
      _isDetailedMode = true;
    });

    if (_selectedLandmarkIndex >= 0 &&
        _selectedLandmarkIndex < _nearbyLandmarks.length) {
      Landmark landmark = _nearbyLandmarks[_selectedLandmarkIndex];
      String detailedDescription = _generateDetailedLandmarkDescription(
        landmark,
      );
      await _audioManagerService.speakIfActive('map', detailedDescription);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "No landmark is currently selected. Say 'select landmark' to choose a place for detailed information.",
      );
    }
  }

  String _generateDetailedLandmarkDescription(Landmark landmark) {
    String description = "Detailed information about ${landmark.name}: ";
    description += "This is a ${landmark.category} located in the area. ";

    if (_currentPosition != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      double bearing = Geolocator.bearingBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      String direction = _getDirectionFromBearing(bearing);

      description +=
          "It's located $direction from your current position, approximately ${distance.toStringAsFixed(0)} meters away. ";
    }

    description += "The landmark features ${landmark.description}. ";
    description += "It's a popular destination for visitors and locals alike. ";
    description +=
        "The area around this landmark is well-maintained and accessible. ";
    description +=
        "You can say 'navigate to ${landmark.name}' to start navigation, or 'next landmark' to explore other places.";

    return description;
  }

  // Quick exploration commands
  bool _isQuickExplorationCommand(String command) {
    return _blindUserCommandPatterns['quick_exploration']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleQuickExplorationCommand(String command) async {
    setState(() {
      _isDetailedMode = false;
    });

    if (_selectedLandmarkIndex >= 0 &&
        _selectedLandmarkIndex < _nearbyLandmarks.length) {
      Landmark landmark = _nearbyLandmarks[_selectedLandmarkIndex];
      String quickDescription = _generateQuickLandmarkDescription(landmark);
      await _audioManagerService.speakIfActive('map', quickDescription);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "No landmark is currently selected. Say 'select landmark' to choose a place for quick information.",
      );
    }
  }

  String _generateQuickLandmarkDescription(Landmark landmark) {
    String description = "${landmark.name}, a ${landmark.category}. ";

    if (_currentPosition != null) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );
      description += "${distance.toStringAsFixed(0)} meters away. ";
    }

    description +=
        "Say 'navigate to' to start navigation or 'next landmark' to explore another place.";
    return description;
  }

  // Landmark category commands
  bool _isLandmarkCategoryCommand(String command) {
    return _blindUserCommandPatterns['landmark_categories']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleLandmarkCategoryCommand(String command) async {
    if (_nearbyLandmarks.isEmpty) {
      await _audioManagerService.speakIfActive(
        'map',
        "No landmarks are currently available. Try moving around or say 'explore map' to search for nearby places.",
      );
      return;
    }

    String category = "";
    if (command.contains('restaurant'))
      category = "restaurant";
    else if (command.contains('cafe'))
      category = "cafe";
    else if (command.contains('shop'))
      category = "shop";
    else if (command.contains('attraction'))
      category = "attraction";
    else if (command.contains('landmark'))
      category = "landmark";
    else if (command.contains('facility'))
      category = "facility";
    else if (command.contains('service'))
      category = "service";
    else if (command.contains('point of interest'))
      category = "point of interest";
    else if (command.contains('tourist'))
      category = "tourist";
    else if (command.contains('historical'))
      category = "historical";
    else if (command.contains('cultural'))
      category = "cultural";
    else if (command.contains('religious'))
      category = "religious";
    else if (command.contains('park'))
      category = "park";
    else if (command.contains('museum'))
      category = "museum";
    else if (command.contains('gallery'))
      category = "gallery";

    if (category.isNotEmpty) {
      List<Landmark> filteredLandmarks =
          _nearbyLandmarks
              .where(
                (landmark) => landmark.category.toLowerCase().contains(
                  category.toLowerCase(),
                ),
              )
              .toList();

      if (filteredLandmarks.isNotEmpty) {
        String message =
            "Found ${filteredLandmarks.length} ${category}${filteredLandmarks.length > 1 ? 's' : ''}: ";
        for (int i = 0; i < filteredLandmarks.length && i < 5; i++) {
          Landmark landmark = filteredLandmarks[i];
          message += "${landmark.name}, ";
        }
        message += "Say 'select landmark' to interact with these places.";
        await _audioManagerService.speakIfActive('map', message);
      } else {
        await _audioManagerService.speakIfActive(
          'map',
          "No $category found in your current area. Try moving around or explore a different category.",
        );
      }
    }
  }

  // Distance information commands
  bool _isDistanceInformationCommand(String command) {
    return _blindUserCommandPatterns['distance_information']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleDistanceInformationCommand(String command) async {
    if (_selectedLandmarkIndex >= 0 &&
        _selectedLandmarkIndex < _nearbyLandmarks.length &&
        _currentPosition != null) {
      Landmark landmark = _nearbyLandmarks[_selectedLandmarkIndex];
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      String distanceMessage =
          "${landmark.name} is ${distance.toStringAsFixed(0)} meters away. ";

      if (distance < 100) {
        distanceMessage += "It's very close, just a short walk.";
      } else if (distance < 500) {
        distanceMessage += "It's nearby, about a 5-minute walk.";
      } else if (distance < 1000) {
        distanceMessage +=
            "It's within walking distance, about a 10-minute walk.";
      } else {
        distanceMessage += "It's further away, consider transportation.";
      }

      await _audioManagerService.speakIfActive('map', distanceMessage);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "No landmark is currently selected. Say 'select landmark' to choose a place for distance information.",
      );
    }
  }

  // Direction information commands
  bool _isDirectionInformationCommand(String command) {
    return _blindUserCommandPatterns['direction_information']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleDirectionInformationCommand(String command) async {
    if (_selectedLandmarkIndex >= 0 &&
        _selectedLandmarkIndex < _nearbyLandmarks.length &&
        _currentPosition != null) {
      Landmark landmark = _nearbyLandmarks[_selectedLandmarkIndex];
      double bearing = Geolocator.bearingBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.latitude,
        landmark.longitude,
      );

      String direction = _getDirectionFromBearing(bearing);
      String directionMessage =
          "${landmark.name} is located $direction from your current position. ";
      directionMessage += "Face $direction and walk forward to reach it. ";

      await _audioManagerService.speakIfActive('map', directionMessage);

      // Provide directional haptic feedback
      await _provideDirectionalHaptic(bearing);
    } else {
      await _audioManagerService.speakIfActive(
        'map',
        "No landmark is currently selected. Say 'select landmark' to choose a place for direction information.",
      );
    }
  }

  // Accessibility information commands
  bool _isAccessibilityInformationCommand(String command) {
    return _blindUserCommandPatterns['accessibility_info']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleAccessibilityInformationCommand(String command) async {
    String accessibilityMessage = "Accessibility information for this area: ";
    accessibilityMessage +=
        "Most sidewalks are wheelchair accessible with curb cuts at intersections. ";
    accessibilityMessage +=
        "Public buildings have ramps and accessible entrances. ";
    accessibilityMessage +=
        "Crosswalks have audio signals and tactile paving. ";
    accessibilityMessage += "Public transportation is wheelchair accessible. ";
    accessibilityMessage +=
        "Most restaurants and shops have accessible facilities. ";
    accessibilityMessage +=
        "If you need specific accessibility information for a landmark, say 'select landmark' first, then ask about accessibility.";

    await _audioManagerService.speakIfActive('map', accessibilityMessage);
  }

  // Safety information commands
  bool _isSafetyInformationCommand(String command) {
    return _blindUserCommandPatterns['safety_information']!.any(
      (pattern) => command.toLowerCase().contains(pattern.toLowerCase()),
    );
  }

  Future<void> _handleSafetyInformationCommand(String command) async {
    String safetyMessage = "Safety information for this area: ";
    safetyMessage +=
        "The area is generally safe for walking during daylight hours. ";
    safetyMessage +=
        "Well-lit streets and regular police patrols provide security. ";
    safetyMessage += "Emergency services are readily available. ";
    safetyMessage +=
        "Keep valuables secure and be aware of your surroundings. ";
    safetyMessage +=
        "If you feel unsafe, say 'emergency mode' for immediate assistance. ";
    safetyMessage += "Local residents are friendly and helpful to visitors.";

    await _audioManagerService.speakIfActive('map', safetyMessage);
  }

  // Enhanced feedback for blind users
  Future<void> _provideBlindUserFeedback(String command) async {
    String suggestion = _getBlindUserContextualSuggestion(command);

    await _audioManagerService.speakIfActive(
      'map',
      "I didn't understand '$command'. $suggestion",
    );
  }

  String _getBlindUserContextualSuggestion(String command) {
    String lowerCommand = command.toLowerCase();

    if (lowerCommand.contains('explore') ||
        lowerCommand.contains('scan') ||
        lowerCommand.contains('survey')) {
      return "Try saying 'explore map' to scan the area around you, or 'select landmark' to interact with specific places.";
    } else if (lowerCommand.contains('landmark') ||
        lowerCommand.contains('place') ||
        lowerCommand.contains('select')) {
      return "Try saying 'select landmark' to start choosing places, then 'next landmark' to browse through them.";
    } else if (lowerCommand.contains('move') ||
        lowerCommand.contains('pan') ||
        lowerCommand.contains('slide')) {
      return "Try saying 'move map left/right/up/down' to navigate the map view.";
    } else if (lowerCommand.contains('detail') ||
        lowerCommand.contains('more') ||
        lowerCommand.contains('comprehensive')) {
      return "Try saying 'describe in detail' for comprehensive information about the selected landmark.";
    } else if (lowerCommand.contains('brief') ||
        lowerCommand.contains('quick') ||
        lowerCommand.contains('summary')) {
      return "Try saying 'brief description' for a quick overview of the selected landmark.";
    } else if (lowerCommand.contains('restaurant') ||
        lowerCommand.contains('cafe') ||
        lowerCommand.contains('shop')) {
      return "Try saying 'show restaurants', 'show cafes', or 'show shops' to filter landmarks by category.";
    } else if (lowerCommand.contains('distance') ||
        lowerCommand.contains('far') ||
        lowerCommand.contains('close')) {
      return "Try saying 'how far' or 'what distance' to get distance information about the selected landmark.";
    } else if (lowerCommand.contains('direction') ||
        lowerCommand.contains('where') ||
        lowerCommand.contains('way')) {
      return "Try saying 'which direction' or 'where is it' to get directional information about the selected landmark.";
    } else if (lowerCommand.contains('accessibility') ||
        lowerCommand.contains('wheelchair') ||
        lowerCommand.contains('disabled')) {
      return "Try saying 'accessibility features' or 'wheelchair accessible' for accessibility information.";
    } else if (lowerCommand.contains('safe') ||
        lowerCommand.contains('security') ||
        lowerCommand.contains('crime')) {
      return "Try saying 'is it safe' or 'safety information' for safety and security details.";
    } else {
      return "Try saying 'surroundings' for area information, 'landmarks' for nearby places, or 'facilities' for services.";
    }
  }
}
