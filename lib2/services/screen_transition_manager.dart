import 'dart:async';
import 'audio_manager_service.dart';

class ScreenTransitionManager {
  static final ScreenTransitionManager _instance =
      ScreenTransitionManager._internal();
  factory ScreenTransitionManager() => _instance;
  ScreenTransitionManager._internal();

  final AudioManagerService _audioManagerService = AudioManagerService();
  final StreamController<String> _transitionController =
      StreamController<String>.broadcast();
  final StreamController<String> _transitionStatusController =
      StreamController<String>.broadcast();

  // Stream for transition events
  Stream<String> get transitionStream => _transitionController.stream;
  Stream<String> get transitionStatusStream =>
      _transitionStatusController.stream;

  // Current active screen
  String? _currentScreen;
  Timer? _transitionTimer;
  bool _isTransitioning = false;

  // Transition timing configuration
  static const Duration _transitionDelay = Duration(milliseconds: 150);
  static const Duration _welcomeDelay = Duration(milliseconds: 500);

  // Initialize the manager
  Future<void> initialize() async {
    print('ScreenTransitionManager initialized');
    _transitionStatusController.add('initialized');
  }

  // Navigate to a screen with smooth transition and enhanced activation
  Future<void> navigateToScreen(
    String screenId, {
    String? transitionMessage,
  }) async {
    if (_isTransitioning) {
      print(
        'Transition already in progress, skipping navigation to: $screenId',
      );
      return;
    }

    print('🔄 Navigating to screen: $screenId');
    _isTransitioning = true;
    _transitionStatusController.add('transitioning:$screenId');

    try {
      // Cancel any ongoing transition
      _transitionTimer?.cancel();

      // Deactivate current screen audio with transition feedback
      if (_currentScreen != null && _currentScreen != screenId) {
        print('🔇 Deactivating audio for: $_currentScreen');
        await _audioManagerService.deactivateScreenAudio(_currentScreen!);

        // Special handling for map screen deactivation
        if (_currentScreen == 'map') {
          await _handleMapScreenDeactivation();
        }

        // Provide transition feedback
        if (transitionMessage != null) {
          await _audioManagerService.speakIfActive(
            _currentScreen!,
            transitionMessage,
          );
        }
      }

      // Update current screen
      _currentScreen = screenId;
      print('✅ Current screen updated to: $_currentScreen');

      // Activate new screen audio with optimized timing
      _transitionTimer = Timer(_transitionDelay, () async {
        print('🔊 Activating audio for: $screenId');
        await _audioManagerService.activateScreenAudio(screenId);
        _transitionController.add('transitioned:$screenId');
        _transitionStatusController.add('activated:$screenId');

        // Provide welcome message for the new screen with delay
        Timer(_welcomeDelay, () async {
          await _provideWelcomeMessage(screenId);
        });
      });
    } catch (e) {
      print('❌ Error during screen transition: $e');
      _transitionStatusController.add('error:$screenId');
    } finally {
      _isTransitioning = false;
      print('✅ Transition completed for: $screenId');
    }
  }

  // Handle map screen deactivation specifically
  Future<void> _handleMapScreenDeactivation() async {
    try {
      // Ensure map-specific audio features are properly stopped
      await _audioManagerService.speakIfActive(
        'map',
        "Deactivating map audio features. Tour guide narration stopped.",
      );

      // Ensure map audio is completely deactivated
      await _audioManagerService.deactivateScreenAudio('map');

      // Small delay to ensure smooth transition
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      print('Error during map screen deactivation: $e');
    }
  }

  // Provide welcome message for the new screen
  Future<void> _provideWelcomeMessage(String screenId) async {
    String welcomeMessage = _getWelcomeMessage(screenId);
    if (welcomeMessage.isNotEmpty) {
      await _audioManagerService.speakIfActive(screenId, welcomeMessage);
      _transitionStatusController.add('welcome_sent:$screenId');
    }
  }

  // Get welcome message for each screen
  String _getWelcomeMessage(String screenId) {
    switch (screenId) {
      case 'home':
        return "Home screen active. Navigation hub. Say 'one' for map, 'two' for tours, 'three' for downloads, 'four' for help.";
      case 'map':
        return "Map screen active. Interactive exploration. Say 'one' to describe surroundings, 'two' to discover places, 'three' for facilities.";
      case 'discover':
        return "Tour discovery screen active. Your tour guide is ready. Say 'one' through 'four' to select tours, 'play' to start, 'next' for next tour, 'previous' for previous tour.";
      case 'downloads':
        return "Downloads screen active. Offline content library. Say 'one' through 'four' to select tours, 'play' to start, 'pause' to pause.";
      case 'help':
        return "Help screen active. Assistance and support. Say 'one' through 'six' for topics, 'pause' to pause, 'play' to resume.";
      default:
        return "";
    }
  }

  // Get current screen
  String? get currentScreen => _currentScreen;

  // Check if a screen is currently active
  bool isScreenActive(String screenId) {
    return _currentScreen == screenId;
  }

  // Check if transition is in progress
  bool get isTransitioning => _isTransitioning;

  // Handle tab change with smooth transition
  Future<void> handleTabChange(int index) async {
    String screenId = _getScreenIdFromIndex(index);
    await navigateToScreen(
      screenId,
      transitionMessage: "Switching to ${_getScreenName(screenId)}",
    );
  }

  // Handle voice navigation command with enhanced feedback and seamless transitions
  Future<void> handleVoiceNavigation(String screen) async {
    String screenId = _getScreenIdFromVoiceCommand(screen);
    String currentScreen = _currentScreen ?? 'home';

    print(
      'Voice navigation request: "$screen" -> screenId: "$screenId", currentScreen: "$currentScreen"',
    );

    // Check if already on the target screen
    if (currentScreen == screenId) {
      print('Already on screen: $screenId');
      await _audioManagerService.speakIfActive(
        screenId,
        "You're already on the ${_getScreenName(screenId)}. What would you like to do?",
      );
      return;
    }

    // Provide immediate feedback for seamless experience
    String transitionMessage =
        "Seamlessly transitioning from ${_getScreenName(currentScreen)} to ${_getScreenName(screenId)}";

    await navigateToScreen(screenId, transitionMessage: transitionMessage);
  }

  // Get screen ID from tab index
  String _getScreenIdFromIndex(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'map';
      case 2:
        return 'discover';
      case 3:
        return 'downloads';
      case 4:
        return 'help';
      default:
        return 'home';
    }
  }

  // Get screen ID from voice command with streamlined number-based navigation
  String _getScreenIdFromVoiceCommand(String command) {
    String normalizedCommand = command.toLowerCase().trim();

    // Streamlined number-based navigation
    if (normalizedCommand == 'one' ||
        normalizedCommand == '1' ||
        normalizedCommand.contains('map') ||
        normalizedCommand.contains('explore')) {
      return 'map';
    } else if (normalizedCommand == 'two' ||
        normalizedCommand == '2' ||
        normalizedCommand.contains('discover') ||
        normalizedCommand.contains('tour')) {
      return 'discover';
    } else if (normalizedCommand == 'three' ||
        normalizedCommand == '3' ||
        normalizedCommand.contains('download') ||
        normalizedCommand.contains('content')) {
      return 'downloads';
    } else if (normalizedCommand == 'four' ||
        normalizedCommand == '4' ||
        normalizedCommand.contains('help') ||
        normalizedCommand.contains('assistance')) {
      return 'help';
    } else if (normalizedCommand.contains('home') ||
        normalizedCommand.contains('main')) {
      return 'home';
    } else {
      // Default to home if command is unclear
      return 'home';
    }
  }

  // Get screen name for user feedback
  String _getScreenName(String screenId) {
    switch (screenId) {
      case 'home':
        return 'Home screen';
      case 'map':
        return 'Map screen';
      case 'discover':
        return 'Discover screen';
      case 'downloads':
        return 'Downloads screen';
      case 'help':
        return 'Help and Support screen';
      default:
        return 'Home screen';
    }
  }

  // Provide transition feedback
  Future<void> provideTransitionFeedback(
    String fromScreen,
    String toScreen,
  ) async {
    String message =
        "Transitioning from ${_getScreenName(fromScreen)} to ${_getScreenName(toScreen)}";
    await _audioManagerService.speakIfActive(fromScreen, message);
  }

  // Get transition status
  String getTransitionStatus() {
    if (_isTransitioning) {
      return 'transitioning';
    } else if (_currentScreen != null) {
      return 'active:$_currentScreen';
    } else {
      return 'idle';
    }
  }

  // Dispose resources
  void dispose() {
    _transitionTimer?.cancel();
    _transitionController.close();
    _transitionStatusController.close();
  }
}
