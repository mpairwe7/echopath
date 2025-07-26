import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'audio_manager_service.dart';
import 'voice_navigation_service.dart';
import 'screen_transition_manager.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final AudioManagerService _audioManager = AudioManagerService();
  final VoiceNavigationService _voiceNavigationService =
      VoiceNavigationService();
  final ScreenTransitionManager _screenTransitionManager =
      ScreenTransitionManager();
  final FlutterTts _tts = FlutterTts();

  // Navigation state
  String _currentScreen = 'home';
  bool _isNavigating = false;
  Timer? _navigationTimer;

  // Stream for navigation events
  final StreamController<NavigationEvent> _navigationController =
      StreamController<NavigationEvent>.broadcast();
  Stream<NavigationEvent> get navigationStream => _navigationController.stream;

  // Initialize the navigation service
  Future<void> initialize() async {
    await _audioManager.initialize();
    await _voiceNavigationService.initialize();
    await _screenTransitionManager.initialize();
    await _initTts();

    // Listen for voice navigation commands
    _voiceNavigationService.screenNavigationStream.listen((screen) {
      _handleVoiceNavigation(screen);
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
  }

  // Handle voice navigation commands
  Future<void> _handleVoiceNavigation(String screen) async {
    if (_isNavigating) {
      await _audioManager.speakIfActive(
        _currentScreen,
        "Navigation in progress. Please wait.",
      );
      return;
    }

    await _navigateToScreen(screen);
  }

  // Seamless navigation following Flutter best practices
  Future<void> _navigateToScreen(String screen) async {
    try {
      _isNavigating = true;

      // Stop current audio for smooth transition
      await _stopCurrentAudio();

      // Provide immediate feedback
      String confirmationMessage = _getNavigationConfirmation(screen);
      await _audioManager.speakIfActive(_currentScreen, confirmationMessage);

      // Update current screen
      String previousScreen = _currentScreen;
      _currentScreen = screen;

      // Notify navigation stream
      _navigationController.add(
        NavigationEvent(
          fromScreen: previousScreen,
          toScreen: screen,
          timestamp: DateTime.now(),
        ),
      );

      // Provide screen-specific instructions
      await Future.delayed(Duration(milliseconds: 500));
      await _provideScreenInstructions(screen);

      // Use screen transition manager for smooth transitions
      await Future.delayed(Duration(milliseconds: 300));
      await _screenTransitionManager.navigateToScreen(screen);
    } catch (e) {
      print('Navigation error: $e');
      await _audioManager.speakIfActive(
        _currentScreen,
        "Navigation failed. Please try again.",
      );
    } finally {
      _isNavigating = false;
    }
  }

  // Stop current audio for smooth transitions
  Future<void> _stopCurrentAudio() async {
    try {
      await _tts.stop();
      await _audioManager.stopAllAudio();
      await Future.delayed(Duration(milliseconds: 200));
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  // Get navigation confirmation message
  String _getNavigationConfirmation(String screen) {
    switch (screen) {
      case 'home':
        return 'Navigating to home screen';
      case 'map':
        return 'Navigating to map screen for location tracking';
      case 'discover':
        return 'Navigating to discover screen for tours';
      case 'downloads':
        return 'Navigating to downloads screen';
      case 'help':
        return 'Navigating to help and support screen';
      default:
        return 'Navigating to $screen screen';
    }
  }

  // Provide screen-specific instructions following Flutter accessibility guidelines
  Future<void> _provideScreenInstructions(String screen) async {
    String instructions = '';

    switch (screen) {
      case 'home':
        instructions =
            "You're on the home screen. Say 'go to map' for navigation, 'go to discover' for tours, 'go to downloads' for offline content, or 'go to help' for assistance.";
        break;
      case 'map':
        instructions =
            "You're on the map screen. Say 'where am I' for your location, 'nearby attractions' to see what's around, 'describe surroundings' for detailed information, or 'play audio' to start tour narration.";
        break;
      case 'discover':
        instructions =
            "You're on the discover screen. Say 'browse tours' to see available tours, 'start tour' to begin a tour, or 'download tour' to save for offline use.";
        break;
      case 'downloads':
        instructions =
            "You're on the downloads screen. Say 'list downloads' to see your saved content, 'play download' to start playing, or 'delete download' to remove content.";
        break;
      case 'help':
        instructions =
            "You're on the help screen. Say 'voice commands help' for command guidance, 'accessibility features' for feature information, or 'tour tips' for usage tips.";
        break;
    }

    if (instructions.isNotEmpty) {
      await _audioManager.speakIfActive(_currentScreen, instructions);
    }
  }

  // Get current screen
  String get currentScreen => _currentScreen;

  // Check if currently navigating
  bool get isNavigating => _isNavigating;

  // Manual navigation method for UI buttons
  Future<void> navigateToScreen(String screen) async {
    await _navigateToScreen(screen);
  }

  // Get navigation history
  List<NavigationEvent> getNavigationHistory() {
    // This would typically be stored in a database
    return [];
  }

  // Dispose resources
  void dispose() {
    _navigationTimer?.cancel();
    _navigationController.close();
  }
}

// Navigation event class for tracking
class NavigationEvent {
  final String fromScreen;
  final String toScreen;
  final DateTime timestamp;

  NavigationEvent({
    required this.fromScreen,
    required this.toScreen,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'NavigationEvent(from: $fromScreen, to: $toScreen, time: $timestamp)';
  }
}
