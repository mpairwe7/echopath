import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'audio_manager_service.dart';
import 'screen_transition_manager.dart';

class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioManagerService _audioManager = AudioManagerService();
  final ScreenTransitionManager _transitionManager = ScreenTransitionManager();

  bool _isListening = false;
  bool _isInitialized = false;
  Timer? _listeningTimer;
  Timer? _continuousListeningTimer;
  Timer? _errorRecoveryTimer;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  // Stream controllers for screen-specific commands
  final StreamController<String> _discoverCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _mapCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _homeCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _downloadsCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _helpCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _voiceStatusController =
      StreamController<String>.broadcast();

  // Streams for UI to listen to
  Stream<String> get discoverCommandStream => _discoverCommandController.stream;
  Stream<String> get mapCommandStream => _mapCommandController.stream;
  Stream<String> get homeCommandStream => _homeCommandController.stream;
  Stream<String> get downloadsCommandStream =>
      _downloadsCommandController.stream;
  Stream<String> get helpCommandStream => _helpCommandController.stream;
  Stream<String> get voiceStatusStream => _voiceStatusController.stream;

  // UI command stream for general UI commands
  Stream<String> get uiCommandStream => _mapCommandController.stream;

  // Tour Discovery specific command patterns
  static const Map<String, List<String>> _discoverCommandPatterns = {
    'find_tours': [
      'find tours',
      'search tours',
      'show tours',
      'available tours',
      'nearby tours',
      'what tours',
      'list tours',
      'find available',
      'show available',
      'tours',
      'find',
      'search',
      'show',
    ],
    'start_tour': [
      'start tour',
      'begin tour',
      'play tour',
      'start',
      'begin',
      'play',
      'go',
      'one',
      'two',
      'three',
      'four',
      'first',
      'second',
      'third',
      'fourth',
    ],
    'describe_tour': [
      'describe tour',
      'tour details',
      'tour info',
      'tell me about tour',
      'describe',
      'details',
      'info',
      'about',
      'what is',
    ],
    'tell_about_place': [
      'tell me about',
      'tell about',
      'describe',
      'what is',
      'about',
      'place info',
      'place details',
    ],
    'refresh': [
      'refresh',
      'update',
      'refresh location',
      'update location',
      'find new',
      'search again',
      'look again',
      'check again',
      'new',
      'again',
    ],
    'list_tours': [
      'list tours',
      'show all tours',
      'tell me all tours',
      'read all tours',
      'hear all tours',
      'all tours',
      'list all',
      'show all',
      'all',
    ],
    'tour_discovery_mode': [
      'tour discovery mode',
      'discovery mode',
      'tour search mode',
      'search mode',
      'tour exploration mode',
      'exploration mode',
      'tour browse mode',
      'browse mode',
      'tour finder mode',
      'finder mode',
    ],
    'place_exploration_mode': [
      'place exploration mode',
      'place mode',
      'location exploration mode',
      'location mode',
      'area exploration mode',
      'area mode',
      'place discovery mode',
      'location discovery mode',
      'area discovery mode',
    ],
    'detailed_info': [
      'detailed information',
      'detailed info',
      'detailed details',
      'comprehensive information',
      'comprehensive info',
      'full information',
      'full details',
      'complete information',
      'complete details',
      'extended information',
      'extended details',
      'in depth information',
      'in depth details',
    ],
    'quick_info': [
      'quick information',
      'quick info',
      'brief information',
      'brief info',
      'short information',
      'short info',
      'summary information',
      'summary info',
      'overview information',
      'overview info',
    ],
    'help': [
      'help',
      'help me',
      'assistance',
      'support',
      'guide',
      'tutorial',
      'help assistance',
      'help support',
      'help guide',
      'help tutorial',
      'get help',
      'need help',
      'want help',
      'help please',
      'assistance please',
      'support please',
      'guide please',
      'tutorial please',
      'discover help',
      'tour help',
      'discovery help',
      'tour discovery help',
      'discover assistance',
      'tour assistance',
      'discovery assistance',
      'tour discovery assistance',
      'discover guide',
      'tour guide',
      'discovery guide',
      'tour discovery guide',
      'discover tutorial',
      'tour tutorial',
      'discovery tutorial',
      'tour discovery tutorial',
    ],
  };

  // Screen-specific command patterns
  static const Map<String, List<String>> _homeCommandPatterns = {
    'navigation': ['one', '1', 'first', 'map', 'go to map'],
    'tours': ['two', '2', 'second', 'discover', 'go to discover'],
    'downloads': ['three', '3', 'third', 'downloads', 'go to downloads'],
    'help': ['four', '4', 'fourth', 'help', 'go to help'],
    'welcome': ['welcome', 'intro', 'introduction'],
    'quick_access': ['quick access', 'navigation', 'options'],
    'status': ['status', 'info', 'information'],
    'help_commands': ['help', 'assistance', 'commands'],
  };

  static const Map<String, List<String>> _downloadsCommandPatterns = {
    'play_tour': [
      'one',
      '1',
      'first',
      'two',
      '2',
      'second',
      'three',
      '3',
      'third',
      'four',
      '4',
      'fourth',
      'play',
      'start',
    ],
    'pause_tour': ['pause', 'pause tour', 'stop', 'stop tour'],
    'resume_tour': ['resume', 'resume tour', 'continue', 'continue tour'],
    'next_tour': ['next', 'next tour', 'skip', 'skip tour'],
    'previous_tour': ['previous', 'previous tour', 'back', 'back tour'],
    'download_all': [
      'download all',
      'download everything',
      'get all',
      'get everything',
    ],
    'delete_downloads': [
      'delete',
      'delete downloads',
      'clear',
      'clear downloads',
    ],
    'show_downloads': [
      'show downloads',
      'list downloads',
      'what downloads',
      'my downloads',
    ],
    'help': ['help', 'assistance', 'commands'],
  };

  static const Map<String, List<String>> _helpCommandPatterns = {
    'navigation_help': ['one', '1', 'first', 'navigation'],
    'map_help': ['two', '2', 'second', 'map'],
    'tours_help': ['three', '3', 'third', 'tours'],
    'downloads_help': ['four', '4', 'fourth', 'downloads'],
    'audio_help': ['five', '5', 'fifth', 'audio'],
    'help_help': ['six', '6', 'sixth', 'help'],
    'read_all': ['read all', 'read all topics', 'all topics', 'everything'],
    'go_back': ['go back', 'back', 'return', 'home'],
    'help': ['help', 'assistance', 'commands'],
  };

  // Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await _initTts();
      await _initSpeechRecognition();
      _isInitialized = true;
      _voiceStatusController.add('initialized');
      return true;
    } catch (e) {
      print('VoiceCommandService initialization error: $e');
      _voiceStatusController.add('error:initialization');
      return false;
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setVoice({
      "name": "en-us-x-sfg#female_1-local",
      "locale": "en-US",
    });
  }

  Future<void> _initSpeechRecognition() async {
    if (_speech.isAvailable) return;

    bool available = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
      debugLogging: true,
    );

    if (!available) {
      throw Exception('Speech recognition not available');
    }
  }

  // Enhanced error handling for speech recognition
  void _onSpeechError(dynamic error) {
    print('Speech recognition error: $error');
    _consecutiveErrors++;

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _handleConsecutiveErrors();
    } else {
      _scheduleErrorRecovery();
    }

    _voiceStatusController.add('error:$error');
  }

  void _onSpeechStatus(String status) {
    print('Speech recognition status: $status');
    _voiceStatusController.add('status:$status');

    if (status == 'listening') {
      _consecutiveErrors = 0; // Reset error count on successful listening
    }
  }

  void _handleConsecutiveErrors() {
    print('Too many consecutive errors, restarting speech recognition');
    _restartSpeechRecognition();
  }

  void _scheduleErrorRecovery() {
    _errorRecoveryTimer?.cancel();
    _errorRecoveryTimer = Timer(const Duration(seconds: 2), () {
      if (_isListening && _consecutiveErrors > 0) {
        _restartSpeechRecognition();
      }
    });
  }

  Future<void> _restartSpeechRecognition() async {
    try {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isListening) {
        await _startListeningCycle();
      }
    } catch (e) {
      print('Error restarting speech recognition: $e');
    }
  }

  // Start continuous listening for screen-specific commands
  Future<void> startContinuousListening() async {
    if (!_isInitialized || _isListening) return;

    _isListening = true;
    _consecutiveErrors = 0;
    await _startListeningCycle();
    _voiceStatusController.add('listening_started');
  }

  // Start listening (alias for startContinuousListening)
  Future<void> startListening() async {
    return startContinuousListening();
  }

  // Stop continuous listening
  Future<void> stopContinuousListening() async {
    _isListening = false;
    _listeningTimer?.cancel();
    _errorRecoveryTimer?.cancel();
    await _speech.stop();
    _voiceStatusController.add('listening_stopped');
  }

  // Stop listening (alias for stopContinuousListening)
  Future<void> stopListening() async {
    return stopContinuousListening();
  }

  Future<void> _startListeningCycle() async {
    if (!_isListening) return;

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          listenMode: stt.ListenMode.confirmation,
          partialResults: false,
        ),
      );

      // Auto-restart listening after timeout
      _listeningTimer = Timer(const Duration(seconds: 10), () {
        if (_isListening) {
          _startListeningCycle();
        }
      });
    } catch (e) {
      print('Error in listening cycle: $e');
      if (_isListening) {
        _scheduleErrorRecovery();
      }
    }
  }

  // Handle speech recognition results with improved processing
  void _onSpeechResult(dynamic result) {
    if (result.finalResult) {
      final command = result.recognizedWords.toLowerCase().trim();
      print('Recognized command: "$command"');

      if (command.isNotEmpty) {
        _processScreenSpecificCommand(command);
      }
    }
  }

  // Process screen-specific commands with context awareness
  Future<void> _processScreenSpecificCommand(String command) async {
    print('Processing screen-specific command: "$command"');

    // IMMEDIATELY stop any ongoing speech when user starts speaking
    await _stopCurrentSpeech();

    // Provide haptic feedback for command recognition
    await _provideHapticFeedback();

    // Get current screen for context-aware processing
    String currentScreen = _transitionManager.currentScreen ?? 'home';

    // Process commands based on current screen
    switch (currentScreen) {
      case 'discover':
        await _processDiscoverCommand(command);
        break;
      case 'map':
        await _processMapCommand(command);
        break;
      case 'home':
        await _processHomeCommand(command);
        break;
      case 'downloads':
        await _processDownloadsCommand(command);
        break;
      case 'help':
        await _processHelpCommand(command);
        break;
      default:
        await _provideDefaultResponse();
    }
  }

  // Process discover screen specific commands
  Future<void> _processDiscoverCommand(String command) async {
    print('Processing discover command: "$command"');

    // Check for discover-specific command patterns
    for (final entry in _discoverCommandPatterns.entries) {
      if (_matchesPattern(command, entry.value)) {
        await _executeDiscoverCommand(entry.key, command);
        return;
      }
    }

    // Check for tour names in the command
    await _checkForTourNameInCommand(command);

    // If no specific command matched, provide helpful feedback
    await _provideDiscoverDefaultResponse();
  }

  // Check if command contains a tour name
  Future<void> _checkForTourNameInCommand(String command) async {
    List<String> tourNames = [
      'murchison falls',
      'kasubi tombs',
      'bwindi forest',
      'lake victoria',
      'murchison',
      'kasubi',
      'bwindi',
      'victoria',
    ];

    // Check for simple number commands first
    if (command == 'one' || command == '1' || command == 'first') {
      await _executeDiscoverCommand('start_tour', 'one');
      return;
    } else if (command == 'two' || command == '2' || command == 'second') {
      await _executeDiscoverCommand('start_tour', 'two');
      return;
    } else if (command == 'three' || command == '3' || command == 'third') {
      await _executeDiscoverCommand('start_tour', 'three');
      return;
    } else if (command == 'four' || command == '4' || command == 'fourth') {
      await _executeDiscoverCommand('start_tour', 'four');
      return;
    }

    for (String tourName in tourNames) {
      if (command.contains(tourName)) {
        if (command.contains('start') ||
            command.contains('begin') ||
            command.contains('play')) {
          await _executeDiscoverCommand('start_tour', 'start tour $tourName');
          return;
        } else if (command.contains('describe') ||
            command.contains('tell') ||
            command.contains('about')) {
          await _executeDiscoverCommand(
            'describe_tour',
            'describe tour $tourName',
          );
          return;
        }
      }
    }
  }

  // Execute discover-specific commands
  Future<void> _executeDiscoverCommand(
    String commandType,
    String fullCommand,
  ) async {
    try {
      switch (commandType) {
        case 'find_tours':
          await _handleDiscoverFindTours();
          break;
        case 'start_tour':
          await _handleDiscoverStartTour(fullCommand);
          break;
        case 'describe_tour':
          await _handleDiscoverDescribeTour(fullCommand);
          break;
        case 'tell_about_place':
          await _handleDiscoverTellAboutPlace(fullCommand);
          break;
        case 'refresh':
          await _handleDiscoverRefresh();
          break;
        case 'list_tours':
          await _handleDiscoverListTours();
          break;
        case 'tour_discovery_mode':
          await _handleDiscoverTourDiscoveryMode();
          break;
        case 'place_exploration_mode':
          await _handleDiscoverPlaceExplorationMode();
          break;
        case 'detailed_info':
          await _handleDiscoverDetailedInfo();
          break;
        case 'quick_info':
          await _handleDiscoverQuickInfo();
          break;
        case 'help':
          await _handleDiscoverHelp();
          break;
      }
    } catch (e) {
      print('Error executing discover command: $e');
      await _provideErrorFeedback();
    }
  }

  // Discover command handlers
  Future<void> _handleDiscoverFindTours() async {
    await _narrateForCurrentScreen(
      "Searching for tours near you.",
      interrupt: true,
    );
    _discoverCommandController.add('find_tours');
  }

  Future<void> _handleDiscoverStartTour(String command) async {
    String tourName = '';
    if (command.contains('start tour')) {
      tourName = command.split('start tour').last.trim();
    } else if (command.contains('begin tour')) {
      tourName = command.split('begin tour').last.trim();
    } else if (command.contains('play tour')) {
      tourName = command.split('play tour').last.trim();
    } else if (command.contains('start')) {
      tourName = command.split('start').last.trim();
    } else if (command.contains('begin')) {
      tourName = command.split('begin').last.trim();
    } else if (command.contains('play')) {
      tourName = command.split('play').last.trim();
    } else if (command.contains('go')) {
      tourName = command.split('go').last.trim();
    }

    if (tourName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Starting tour: $tourName.",
        interrupt: true,
      );
      _discoverCommandController.add('start_tour:$tourName');
    } else {
      await _narrateForCurrentScreen(
        "Say 'start tour' plus tour name.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDiscoverDescribeTour(String command) async {
    String tourName = '';
    if (command.contains('describe tour')) {
      tourName = command.split('describe tour').last.trim();
    } else if (command.contains('tour details')) {
      tourName = command.split('tour details').last.trim();
    } else if (command.contains('tour info')) {
      tourName = command.split('tour info').last.trim();
    } else if (command.contains('tell me about tour')) {
      tourName = command.split('tell me about tour').last.trim();
    } else if (command.contains('describe')) {
      tourName = command.split('describe').last.trim();
    } else if (command.contains('details')) {
      tourName = command.split('details').last.trim();
    } else if (command.contains('info')) {
      tourName = command.split('info').last.trim();
    } else if (command.contains('about')) {
      tourName = command.split('about').last.trim();
    }

    if (tourName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Tour details for: $tourName.",
        interrupt: true,
      );
      _discoverCommandController.add('describe_tour:$tourName');
    } else {
      await _narrateForCurrentScreen(
        "Say 'describe tour' plus tour name.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDiscoverTellAboutPlace(String command) async {
    String placeName = '';
    if (command.contains('tell me about')) {
      placeName = command.split('tell me about').last.trim();
    } else if (command.contains('tell about')) {
      placeName = command.split('tell about').last.trim();
    } else if (command.contains('describe')) {
      placeName = command.split('describe').last.trim();
    } else if (command.contains('what is')) {
      placeName = command.split('what is').last.trim();
    } else if (command.contains('about')) {
      placeName = command.split('about').last.trim();
    }

    if (placeName.isNotEmpty) {
      await _narrateForCurrentScreen("About $placeName.", interrupt: true);
      _discoverCommandController.add('tell_about_place:$placeName');
    } else {
      await _narrateForCurrentScreen(
        "Say 'tell me about' plus place name.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDiscoverRefresh() async {
    await _narrateForCurrentScreen(
      "Refreshing location and tours.",
      interrupt: true,
    );
    _discoverCommandController.add('refresh');
  }

  Future<void> _handleDiscoverListTours() async {
    await _narrateForCurrentScreen("Listing all tours.", interrupt: true);
    _discoverCommandController.add('list_tours');
  }

  Future<void> _handleDiscoverTourDiscoveryMode() async {
    await _narrateForCurrentScreen(
      "Tour discovery mode activated.",
      interrupt: true,
    );
    _discoverCommandController.add('tour_discovery_mode');
  }

  Future<void> _handleDiscoverPlaceExplorationMode() async {
    await _narrateForCurrentScreen(
      "Place exploration mode activated.",
      interrupt: true,
    );
    _discoverCommandController.add('place_exploration_mode');
  }

  Future<void> _handleDiscoverDetailedInfo() async {
    await _narrateForCurrentScreen(
      "Detailed information mode enabled.",
      interrupt: true,
    );
    _discoverCommandController.add('detailed_info');
  }

  Future<void> _handleDiscoverQuickInfo() async {
    await _narrateForCurrentScreen(
      "Quick information mode enabled.",
      interrupt: true,
    );
    _discoverCommandController.add('quick_info');
  }

  Future<void> _handleDiscoverHelp() async {
    await _narrateForCurrentScreen(
      "Tour Discovery commands: 'find tours' to search. 'start tour' plus name to begin. 'describe tour' plus name for details. 'tell me about' plus place name. 'refresh' to update. 'list tours' to hear all. Say tour name to start.",
      interrupt: true,
    );
    _discoverCommandController.add('help');
  }

  // Process other screen commands (placeholder implementations)
  Future<void> _processMapCommand(String command) async {
    // Map-specific command processing
    await _provideDefaultResponse();
  }

  Future<void> _processHomeCommand(String command) async {
    // Home-specific command processing
    await _provideDefaultResponse();
  }

  Future<void> _processDownloadsCommand(String command) async {
    // Downloads-specific command processing
    await _provideDefaultResponse();
  }

  Future<void> _processHelpCommand(String command) async {
    // Help-specific command processing
    await _provideDefaultResponse();
  }

  // Improved pattern matching with priority for exact matches
  bool _matchesPattern(String command, List<String> patterns) {
    for (final pattern in patterns) {
      // Check for exact match first
      if (command.trim() == pattern.trim()) {
        return true;
      }
      // Check for contains match
      if (command.contains(pattern) || pattern.contains(command)) {
        return true;
      }
    }
    return false;
  }

  // Stop current speech immediately when user starts speaking
  Future<void> _stopCurrentSpeech() async {
    try {
      await _tts.stop();
      await _audioManager.stopAllAudio();
      print('Stopped current speech to listen to user');
    } catch (e) {
      print('Error stopping speech: $e');
    }
  }

  // Centralized method to handle screen-specific narration
  Future<void> _narrateForCurrentScreen(
    String text, {
    bool interrupt = false,
  }) async {
    try {
      String currentScreen = _transitionManager.currentScreen ?? 'home';
      await _audioManager.narrateForScreen(
        currentScreen,
        text,
        interrupt: interrupt,
      );
    } catch (e) {
      print('Error narrating for current screen: $e');
    }
  }

  // Provide discover-specific default response
  Future<void> _provideDiscoverDefaultResponse() async {
    await _narrateForCurrentScreen(
      "I didn't understand that command. For tour discovery, you can say 'find tours' to search for available tours, 'start tour' followed by tour name to begin, 'describe tour' followed by tour name for details, 'tell me about' followed by place name for area information, 'refresh' to update location, or 'help' for all available commands.",
      interrupt: true,
    );
  }

  // Provide default response
  Future<void> _provideDefaultResponse() async {
    await _narrateForCurrentScreen(
      "I didn't understand that command. Say 'help' for available commands.",
      interrupt: true,
    );
  }

  // Provide error feedback
  Future<void> _provideErrorFeedback() async {
    await _narrateForCurrentScreen(
      "Sorry, there was an error. Please try again.",
      interrupt: true,
    );
  }

  // Provide haptic feedback
  Future<void> _provideHapticFeedback() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  }

  // Get current listening status
  bool get isListening => _isListening;

  // Get initialization status
  bool get isInitialized => _isInitialized;

  // Dispose resources
  void dispose() {
    stopContinuousListening();
    _listeningTimer?.cancel();
    _continuousListeningTimer?.cancel();
    _errorRecoveryTimer?.cancel();
    _discoverCommandController.close();
    _mapCommandController.close();
    _homeCommandController.close();
    _downloadsCommandController.close();
    _helpCommandController.close();
    _voiceStatusController.close();
  }
}
