import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import '../models/landmark.dart';
import 'audio_manager_service.dart';

// Narration modes enum
enum NarrationMode {
  silent, // No automatic narration
  minimal, // Only essential information
  standard, // Balanced narration
  detailed, // Comprehensive information
  continuous, // Frequent updates
  immersive, // Enhanced immersive experience
}

// Narration detail levels
enum NarrationDetail {
  brief, // Short, essential info
  medium, // Balanced detail
  comprehensive, // Full details
  immersive, // Rich, engaging details
}

// Emotional tone for narration
enum NarrationTone {
  neutral, // Standard informative tone
  enthusiastic, // Excited and engaging
  calm, // Relaxed and soothing
  urgent, // Important information
  friendly, // Warm and welcoming
}

class AudioNarrationService {
  static final AudioNarrationService _instance =
      AudioNarrationService._internal();
  factory AudioNarrationService() => _instance;
  AudioNarrationService._internal();

  final FlutterTts _tts = FlutterTts();
  final AudioManagerService _audioManager = AudioManagerService();

  // Narration state
  String _lastNarratedLocation = '';
  double _lastNarratedBearing = 0.0;
  Position? _currentPosition;
  List<Landmark> _nearbyLandmarks = [];

  // User control settings
  NarrationMode _narrationMode = NarrationMode.standard;
  NarrationDetail _narrationDetail = NarrationDetail.medium;
  NarrationTone _narrationTone = NarrationTone.friendly;
  bool _enableLocationNarration = true;
  bool _enableLandmarkNarration = true;
  bool _enableSafetyNarration = true;
  bool _enableStreetNarration = true;
  bool _enableEmotionalNarration = true;
  bool _enableContextualNarration = true;
  bool _enableRealTimeUpdates = true;
  int _maxNarrationLength = 150; // Increased for immersive experience
  bool _enableHapticFeedback = true;

  // Enhanced narration settings
  static const double _bearingChangeThreshold = 30.0; // degrees
  static const double _distanceThreshold = 50.0; // meters
  static const Duration _narrationCooldown = Duration(seconds: 15);
  DateTime? _lastNarrationTime;

  // Real-time data tracking
  Map<String, dynamic> _realTimeData = {};
  List<String> _narrationHistory = [];
  int _narrationCount = 0;

  // Initialize the service
  Future<void> initialize() async {
    await _initTts();
    _setupAudioManagerIntegration();
    _initializeRealTimeData();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  // Setup integration with AudioManagerService
  void _setupAudioManagerIntegration() {
    // Listen to narration control events from AudioManagerService
    _audioManager.narrationControlStream.listen((event) {
      if (event.startsWith('trigger:map')) {
        _handleNarrationTrigger();
      }
    });
  }

  // Initialize real-time data tracking
  void _initializeRealTimeData() {
    _realTimeData = {
      'weather': 'clear',
      'temperature': '25°C',
      'humidity': '65%',
      'air_quality': 'good',
      'crowd_level': 'moderate',
      'noise_level': 'normal',
      'lighting': 'daylight',
      'accessibility': 'excellent',
      'safety_level': 'safe',
      'transportation': 'available',
    };
  }

  // Handle narration trigger from AudioManagerService
  Future<void> _handleNarrationTrigger() async {
    if (_currentPosition == null) return;

    // Don't narrate in silent mode
    if (_narrationMode == NarrationMode.silent) {
      return;
    }

    // Check cooldown to prevent spam
    if (_lastNarrationTime != null &&
        DateTime.now().difference(_lastNarrationTime!) < _narrationCooldown) {
      return;
    }

    _lastNarrationTime = DateTime.now();

    // Generate and speak enhanced narration
    await _generateAndSpeakEnhancedNarration();
  }

  // Update current position and landmarks
  void updatePosition(Position position) {
    _currentPosition = position;
    _updateRealTimeData();
  }

  void updateLandmarks(List<Landmark> landmarks) {
    _nearbyLandmarks = landmarks;
    _updateRealTimeData();
  }

  // Update real-time data based on current context
  void _updateRealTimeData() {
    if (_currentPosition == null) return;

    // Simulate real-time data updates
    _realTimeData['crowd_level'] = _getCrowdLevel();
    _realTimeData['noise_level'] = _getNoiseLevel();
    _realTimeData['lighting'] = _getLightingCondition();
    _realTimeData['accessibility'] = _getAccessibilityLevel();
    _realTimeData['safety_level'] = _getSafetyLevel();
    _realTimeData['transportation'] = _getTransportationStatus();
  }

  String _getCrowdLevel() {
    // Simulate crowd level based on time and landmarks
    final hour = DateTime.now().hour;
    if (hour >= 8 && hour <= 18) {
      return _nearbyLandmarks.length > 5 ? 'busy' : 'moderate';
    } else {
      return 'quiet';
    }
  }

  String _getNoiseLevel() {
    final hour = DateTime.now().hour;
    if (hour >= 7 && hour <= 22) {
      return 'normal';
    } else {
      return 'quiet';
    }
  }

  String _getLightingCondition() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour <= 18) {
      return 'daylight';
    } else {
      return 'evening';
    }
  }

  String _getAccessibilityLevel() {
    // Simulate accessibility based on landmarks
    final accessibleLandmarks =
        _nearbyLandmarks
            .where((l) => l.category.toLowerCase().contains('facility'))
            .length;
    return accessibleLandmarks > 2 ? 'excellent' : 'good';
  }

  String _getSafetyLevel() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour <= 22) {
      return 'safe';
    } else {
      return 'moderate';
    }
  }

  String _getTransportationStatus() {
    return _nearbyLandmarks
            .where((l) => l.category.toLowerCase().contains('transport'))
            .isNotEmpty
        ? 'available'
        : 'limited';
  }

  // User control methods
  void setNarrationMode(NarrationMode mode) {
    _narrationMode = mode;
    print('🎤 Narration mode changed to: ${mode.name}');
  }

  void setNarrationDetail(NarrationDetail detail) {
    _narrationDetail = detail;
    print('📝 Narration detail level changed to: ${detail.name}');
  }

  void setNarrationTone(NarrationTone tone) {
    _narrationTone = tone;
    print('🎭 Narration tone changed to: ${tone.name}');
  }

  void toggleLocationNarration() {
    _enableLocationNarration = !_enableLocationNarration;
    print(
      '📍 Location narration: ${_enableLocationNarration ? "enabled" : "disabled"}',
    );
  }

  void toggleLandmarkNarration() {
    _enableLandmarkNarration = !_enableLandmarkNarration;
    print(
      '🏛️ Landmark narration: ${_enableLandmarkNarration ? "enabled" : "disabled"}',
    );
  }

  void toggleSafetyNarration() {
    _enableSafetyNarration = !_enableSafetyNarration;
    print(
      '🛡️ Safety narration: ${_enableSafetyNarration ? "enabled" : "disabled"}',
    );
  }

  void toggleStreetNarration() {
    _enableStreetNarration = !_enableStreetNarration;
    print(
      '🛣️ Street narration: ${_enableStreetNarration ? "enabled" : "disabled"}',
    );
  }

  void toggleEmotionalNarration() {
    _enableEmotionalNarration = !_enableEmotionalNarration;
    print(
      '😊 Emotional narration: ${_enableEmotionalNarration ? "enabled" : "disabled"}',
    );
  }

  void toggleContextualNarration() {
    _enableContextualNarration = !_enableContextualNarration;
    print(
      '🎯 Contextual narration: ${_enableContextualNarration ? "enabled" : "disabled"}',
    );
  }

  void toggleRealTimeUpdates() {
    _enableRealTimeUpdates = !_enableRealTimeUpdates;
    print(
      '⏰ Real-time updates: ${_enableRealTimeUpdates ? "enabled" : "disabled"}',
    );
  }

  // Enhanced narration generation with immersive features
  Future<void> _generateAndSpeakEnhancedNarration() async {
    if (_currentPosition == null) return;

    final List<String> narrationParts = [];

    // Enhanced location description with emotional tone
    if (_enableLocationNarration &&
        (_narrationMode == NarrationMode.standard ||
            _narrationMode == NarrationMode.detailed ||
            _narrationMode == NarrationMode.continuous ||
            _narrationMode == NarrationMode.immersive)) {
      final locationDesc = await _getEnhancedLocationDescription();
      if (locationDesc != _lastNarratedLocation) {
        narrationParts.add(locationDesc);
        _lastNarratedLocation = locationDesc;
      }
    }

    // Enhanced nearby features with contextual awareness
    if (_enableLandmarkNarration &&
        (_narrationMode == NarrationMode.detailed ||
            _narrationMode == NarrationMode.continuous ||
            _narrationMode == NarrationMode.immersive)) {
      final nearbyFeatures = await _getEnhancedNearbyFeatures();
      if (nearbyFeatures.isNotEmpty) {
        narrationParts.add(nearbyFeatures);
      }
    }

    // Real-time environmental data
    if (_enableRealTimeUpdates &&
        (_narrationMode == NarrationMode.detailed ||
            _narrationMode == NarrationMode.immersive)) {
      final realTimeInfo = await _getRealTimeEnvironmentalData();
      if (realTimeInfo.isNotEmpty) {
        narrationParts.add(realTimeInfo);
      }
    }

    // Enhanced street and intersection information
    if (_enableStreetNarration &&
        (_narrationMode == NarrationMode.standard ||
            _narrationMode == NarrationMode.detailed ||
            _narrationMode == NarrationMode.immersive)) {
      final streetInfo = await _getEnhancedStreetInformation();
      if (streetInfo.isNotEmpty) {
        narrationParts.add(streetInfo);
      }
    }

    // Enhanced safety information with urgency detection
    if (_enableSafetyNarration &&
        (_narrationMode == NarrationMode.standard ||
            _narrationMode == NarrationMode.detailed ||
            _narrationMode == NarrationMode.continuous ||
            _narrationMode == NarrationMode.immersive)) {
      final safetyInfo = await _getEnhancedSafetyInformation();
      if (safetyInfo.isNotEmpty) {
        narrationParts.add(safetyInfo);
      }
    }

    // Combine and speak only if map screen is still active
    if (narrationParts.isNotEmpty && _audioManager.isScreenAudioActive('map')) {
      String fullNarration = narrationParts.join('. ');

      // Apply emotional tone
      fullNarration = _applyEmotionalTone(fullNarration);

      // Apply detail level filtering
      fullNarration = _applyDetailLevelFiltering(fullNarration);

      // Apply length limit
      if (_maxNarrationLength > 0) {
        fullNarration = _limitNarrationLength(fullNarration);
      }

      if (fullNarration.isNotEmpty) {
        try {
          await _audioManager.speakIfActive('map', fullNarration);

          // Store narration history
          _narrationHistory.add(fullNarration);
          if (_narrationHistory.length > 10) {
            _narrationHistory.removeAt(0);
          }

          // Provide enhanced haptic feedback
          if (_enableHapticFeedback) {
            await _provideEnhancedHapticFeedback();
          }

          _narrationCount++;
        } catch (e) {
          print('❌ Error in enhanced narration: $e');
        }
      }
    }
  }

  // Apply emotional tone to narration
  String _applyEmotionalTone(String narration) {
    if (!_enableEmotionalNarration) return narration;

    switch (_narrationTone) {
      case NarrationTone.enthusiastic:
        return _addEnthusiasm(narration);
      case NarrationTone.calm:
        return _addCalmness(narration);
      case NarrationTone.urgent:
        return _addUrgency(narration);
      case NarrationTone.friendly:
        return _addFriendliness(narration);
      case NarrationTone.neutral:
      default:
        return narration;
    }
  }

  String _addEnthusiasm(String narration) {
    if (narration.contains('amazing')) return narration;
    if (narration.contains('wonderful')) return narration;

    // Add enthusiastic modifiers
    narration = narration.replaceAll(
      'You are',
      'You\'re in an amazing location',
    );
    narration = narration.replaceAll('There are', 'There are wonderful');
    narration = narration.replaceAll('nearby', 'amazing nearby');

    return narration;
  }

  String _addCalmness(String narration) {
    if (narration.contains('peaceful')) return narration;
    if (narration.contains('tranquil')) return narration;

    // Add calming modifiers
    narration = narration.replaceAll('You are', 'You\'re in a peaceful area');
    narration = narration.replaceAll('busy', 'moderately busy');
    narration = narration.replaceAll('noisy', 'comfortably active');

    return narration;
  }

  String _addUrgency(String narration) {
    if (narration.contains('important')) return narration;
    if (narration.contains('urgent')) return narration;

    // Add urgency modifiers
    narration = narration.replaceAll('You are', 'You\'re currently in');
    narration = narration.replaceAll('nearby', 'important nearby');
    narration = narration.replaceAll('available', 'readily available');

    return narration;
  }

  String _addFriendliness(String narration) {
    if (narration.contains('welcome')) return narration;
    if (narration.contains('friendly')) return narration;

    // Add friendly modifiers
    narration = narration.replaceAll('You are', 'Welcome! You\'re in');
    narration = narration.replaceAll('There are', 'You\'ll find');
    narration = narration.replaceAll('nearby', 'friendly nearby');

    return narration;
  }

  // Apply detail level filtering to narration
  String _applyDetailLevelFiltering(String narration) {
    switch (_narrationDetail) {
      case NarrationDetail.brief:
        // Keep only essential information
        if (narration.contains('coordinates')) {
          return narration.split('coordinates')[0] + 'coordinates';
        }
        return narration.split('. ').take(1).join('. ');

      case NarrationDetail.medium:
        // Keep balanced information
        return narration;

      case NarrationDetail.comprehensive:
        // Keep all information
        return narration;

      case NarrationDetail.immersive:
        // Add immersive elements
        return _addImmersiveElements(narration);
    }
  }

  String _addImmersiveElements(String narration) {
    // Add sensory details and immersive language
    if (narration.contains('Kampala')) {
      narration += ' The vibrant energy of this dynamic city surrounds you.';
    }

    if (narration.contains('landmarks')) {
      narration +=
          ' Each location tells a unique story waiting to be discovered.';
    }

    if (narration.contains('facilities')) {
      narration +=
          ' Everything you need is thoughtfully arranged for your convenience.';
    }

    return narration;
  }

  // Limit narration length to specified word count
  String _limitNarrationLength(String narration) {
    final words = narration.split(' ');
    if (words.length <= _maxNarrationLength) {
      return narration;
    }

    return words.take(_maxNarrationLength).join(' ') + '...';
  }

  // Provide enhanced haptic feedback for narration
  Future<void> _provideEnhancedHapticFeedback() async {
    if (await Vibration.hasVibrator() ?? false) {
      // Different haptic patterns based on narration type
      switch (_narrationTone) {
        case NarrationTone.urgent:
          Vibration.vibrate(duration: 200);
          await Future.delayed(Duration(milliseconds: 100));
          Vibration.vibrate(duration: 200);
          break;
        case NarrationTone.enthusiastic:
          Vibration.vibrate(duration: 100);
          await Future.delayed(Duration(milliseconds: 50));
          Vibration.vibrate(duration: 100);
          break;
        default:
          Vibration.vibrate(duration: 50);
      }
    }
  }

  // Enhanced location description with emotional and contextual elements
  Future<String> _getEnhancedLocationDescription() async {
    if (_currentPosition == null) return '';

    String description = '';

    // Base location description
    if (_narrationMode == NarrationMode.immersive) {
      description =
          'You\'re standing in the heart of Kampala, Uganda\'s vibrant capital city. ';
      description +=
          'The rich cultural tapestry of this dynamic metropolis surrounds you. ';
    } else {
      description = 'You are in Kampala, Uganda. ';
    }

    // Add real-time context
    if (_enableRealTimeUpdates) {
      description +=
          'The current atmosphere is ${_realTimeData['crowd_level']} with ${_realTimeData['noise_level']} activity levels. ';
      description +=
          'The ${_realTimeData['lighting']} creates a ${_realTimeData['safety_level']} environment for exploration. ';
    }

    // Add landmark context
    if (_nearbyLandmarks.isNotEmpty) {
      if (_narrationMode == NarrationMode.immersive) {
        description +=
            'Around you, ${_nearbyLandmarks.length} fascinating destinations await your discovery. ';
        description +=
            'Each location offers unique experiences and cultural insights. ';
      } else {
        description +=
            'There are ${_nearbyLandmarks.length} points of interest nearby. ';
      }
    }

    return description;
  }

  // Enhanced nearby features with immersive descriptions
  Future<String> _getEnhancedNearbyFeatures() async {
    if (_nearbyLandmarks.isEmpty) return '';

    String features = '';

    if (_narrationMode == NarrationMode.immersive) {
      features = 'Let me introduce you to the amazing places around you: ';

      // Group landmarks by category for better organization
      Map<String, List<Landmark>> categories = {};
      for (var landmark in _nearbyLandmarks) {
        categories.putIfAbsent(landmark.category, () => []).add(landmark);
      }

      // Describe each category
      categories.forEach((category, landmarks) {
        features +=
            'You\'ll find ${landmarks.length} ${category}${landmarks.length > 1 ? 's' : ''} nearby. ';
        for (int i = 0; i < landmarks.length && i < 2; i++) {
          final landmark = landmarks[i];
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            landmark.latitude,
            landmark.longitude,
          );
          features +=
              '${landmark.name} is just ${distance.toStringAsFixed(0)} meters away. ';
        }
      });
    } else {
      features = 'Nearby attractions include: ';
      for (int i = 0; i < _nearbyLandmarks.length && i < 3; i++) {
        final landmark = _nearbyLandmarks[i];
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          landmark.latitude,
          landmark.longitude,
        );
        features +=
            '${landmark.name}, ${distance.toStringAsFixed(0)} meters away. ';
      }
    }

    return features;
  }

  // Real-time environmental data narration
  Future<String> _getRealTimeEnvironmentalData() async {
    String data = '';

    if (_narrationMode == NarrationMode.immersive) {
      data = 'Current conditions enhance your experience: ';
      data +=
          'The weather is ${_realTimeData['weather']} with a comfortable ${_realTimeData['temperature']}. ';
      data +=
          'Air quality is ${_realTimeData['air_quality']}, perfect for outdoor exploration. ';
      data +=
          'The area has ${_realTimeData['accessibility']} accessibility features. ';
      data +=
          'Public transportation is ${_realTimeData['transportation']} for your convenience. ';
    } else {
      data =
          'Weather: ${_realTimeData['weather']}, ${_realTimeData['temperature']}. ';
      data += 'Air quality: ${_realTimeData['air_quality']}. ';
    }

    return data;
  }

  // Enhanced street information with safety context
  Future<String> _getEnhancedStreetInformation() async {
    String streetInfo = '';

    if (_narrationMode == NarrationMode.immersive) {
      streetInfo =
          'The streets around you are well-maintained and designed for easy navigation. ';
      streetInfo +=
          'Sidewalks are ${_realTimeData['accessibility']} with clear pathways. ';
      streetInfo +=
          'Crosswalks have audio signals and tactile paving for safe crossing. ';
      streetInfo +=
          'Street lighting provides ${_realTimeData['safety_level']} visibility. ';
    } else {
      streetInfo = 'Streets are well-maintained with good accessibility. ';
      streetInfo += 'Crosswalks have safety features. ';
    }

    return streetInfo;
  }

  // Enhanced safety information with urgency detection
  Future<String> _getEnhancedSafetyInformation() async {
    String safetyInfo = '';

    if (_narrationMode == NarrationMode.immersive) {
      safetyInfo = 'Your safety is our priority: ';
      safetyInfo +=
          'The area is ${_realTimeData['safety_level']} with regular security patrols. ';
      safetyInfo += 'Emergency services are readily available if needed. ';
      safetyInfo +=
          'The ${_realTimeData['crowd_level']} environment provides natural safety through community presence. ';
      safetyInfo +=
          'Stay aware of your surroundings and trust your instincts. ';
    } else {
      safetyInfo = 'Safety: The area is ${_realTimeData['safety_level']}. ';
      safetyInfo += 'Emergency services are available. ';
    }

    return safetyInfo;
  }

  // Get current narration settings
  NarrationMode get currentMode => _narrationMode;
  NarrationDetail get currentDetail => _narrationDetail;
  NarrationTone get currentTone => _narrationTone;
  bool get isLocationNarrationEnabled => _enableLocationNarration;
  bool get isLandmarkNarrationEnabled => _enableLandmarkNarration;
  bool get isSafetyNarrationEnabled => _enableSafetyNarration;
  bool get isStreetNarrationEnabled => _enableStreetNarration;
  bool get isEmotionalNarrationEnabled => _enableEmotionalNarration;
  bool get isContextualNarrationEnabled => _enableContextualNarration;
  bool get isRealTimeUpdatesEnabled => _enableRealTimeUpdates;

  // Get narration statistics
  int get narrationCount => _narrationCount;
  List<String> get narrationHistory => List.unmodifiable(_narrationHistory);
  Map<String, dynamic> get realTimeData => Map.unmodifiable(_realTimeData);

  // Start narration
  void startNarration() {
    print('🎤 Enhanced narration started');
  }

  // Stop narration
  void stopNarration() {
    print('🔇 Enhanced narration stopped');
  }

  // Pause narration
  void pauseNarration() {
    print('⏸️ Enhanced narration paused');
  }

  // Resume narration
  void resumeNarration() {
    print('▶️ Enhanced narration resumed');
  }

  // Dispose resources
  void dispose() {
    _tts.stop();
  }
}
