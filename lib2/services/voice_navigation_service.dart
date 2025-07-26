import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'audio_manager_service.dart';
import 'screen_transition_manager.dart';

class VoiceNavigationService {
  static final VoiceNavigationService _instance =
      VoiceNavigationService._internal();
  factory VoiceNavigationService() => _instance;
  VoiceNavigationService._internal();

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

  // Stream controllers for navigation events
  final StreamController<String> _navigationCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _screenNavigationController =
      StreamController<String>.broadcast();
  final StreamController<String> _mapCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _homeCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _discoverCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _downloadsCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _helpCommandController =
      StreamController<String>.broadcast();
  final StreamController<String> _voiceStatusController =
      StreamController<String>.broadcast();

  // Streams for UI to listen to
  Stream<String> get navigationCommandStream =>
      _navigationCommandController.stream;
  Stream<String> get screenNavigationStream =>
      _screenNavigationController.stream;
  Stream<String> get mapCommandStream => _mapCommandController.stream;
  Stream<String> get homeCommandStream => _homeCommandController.stream;
  Stream<String> get discoverCommandStream => _discoverCommandController.stream;
  Stream<String> get downloadsCommandStream =>
      _downloadsCommandController.stream;
  Stream<String> get helpCommandStream => _helpCommandController.stream;
  Stream<String> get voiceStatusStream => _voiceStatusController.stream;

  // Enhanced navigation command patterns for seamless navigation from any screen
  static const Map<String, List<String>> _navigationPatterns = {
    'go_home': [
      'go home',
      'go to home',
      'home screen',
      'main screen',
      'dashboard',
      'main menu',
      'return to home',
      'back to home',
      'take me home',
      'navigate home',
      'home',
      'main',
      'main page',
      'start page',
      'landing page',
      'home page',
      'go to main',
      'go to dashboard',
      'return to main',
      'back to main',
      'switch to home',
      'change to home',
      'move to home',
      'open home',
      'show home',
      'display home',
      'bring up home',
      'load home',
      'access home',
      'enter home',
    ],
    'go_map': [
      'go to map',
      'open map',
      'show map',
      'map screen',
      'location tracking',
      'map',
      'location',
      'tracking',
      'map page',
      'location page',
      'tracking page',
      'go to location',
      'go to tracking',
      'show location',
      'show tracking',
      'open location',
      'open tracking',
      'navigate to map',
      'navigate to location',
      'take me to map',
      'take me to location',
      'switch to map',
      'change to map',
      'move to map',
      'display map',
      'bring up map',
      'load map',
      'access map',
      'enter map',
      'switch to location',
      'change to location',
      'move to location',
      'display location',
      'bring up location',
      'load location',
      'access location',
      'enter location',
    ],
    'go_discover': [
      'go to discover',
      'open discover',
      'show discover',
      'discover screen',
      'tour discovery',
      'find tours',
      'discover',
      'explore',
      'tours',
      'discover page',
      'explore page',
      'tours page',
      'tour page',
      'go to explore',
      'go to tours',
      'show tours',
      'open tours',
      'open explore',
      'show explore',
      'find attractions',
      'discover attractions',
      'explore attractions',
      'tour discovery page',
      'attractions page',
      'navigate to discover',
      'navigate to explore',
      'take me to discover',
      'take me to explore',
      'switch to discover',
      'change to discover',
      'move to discover',
      'display discover',
      'bring up discover',
      'load discover',
      'access discover',
      'enter discover',
      'switch to explore',
      'change to explore',
      'move to explore',
      'display explore',
      'bring up explore',
      'load explore',
      'access explore',
      'enter explore',
      'switch to tours',
      'change to tours',
      'move to tours',
      'display tours',
      'bring up tours',
      'load tours',
      'access tours',
      'enter tours',
    ],
    'go_downloads': [
      'go to downloads',
      'open downloads',
      'show downloads',
      'downloads screen',
      'saved tours',
      'offline tours',
      'downloads',
      'saved',
      'offline',
      'my downloads',
      'downloads page',
      'saved page',
      'offline page',
      'go to saved',
      'go to offline',
      'show saved',
      'show offline',
      'open saved',
      'open offline',
      'my saved tours',
      'my offline tours',
      'downloaded content',
      'offline content',
      'saved content',
      'navigate to downloads',
      'navigate to saved',
      'take me to downloads',
      'take me to saved',
      'switch to downloads',
      'change to downloads',
      'move to downloads',
      'display downloads',
      'bring up downloads',
      'load downloads',
      'access downloads',
      'enter downloads',
      'switch to saved',
      'change to saved',
      'move to saved',
      'display saved',
      'bring up saved',
      'load saved',
      'access saved',
      'enter saved',
      'switch to offline',
      'change to offline',
      'move to offline',
      'display offline',
      'bring up offline',
      'load offline',
      'access offline',
      'enter offline',
    ],
    'go_help': [
      'go to help',
      'open help',
      'show help',
      'help screen',
      'support',
      'help and support',
      'help',
      'support',
      'help page',
      'support page',
      'go to support',
      'show support',
      'open support',
      'help and support page',
      'assistance',
      'go to assistance',
      'show assistance',
      'open assistance',
      'help center',
      'support center',
      'navigate to help',
      'navigate to support',
      'take me to help',
      'take me to support',
      'switch to help',
      'change to help',
      'move to help',
      'display help',
      'bring up help',
      'load help',
      'access help',
      'enter help',
      'switch to support',
      'change to support',
      'move to support',
      'display support',
      'bring up support',
      'load support',
      'access support',
      'enter support',
      'switch to assistance',
      'change to assistance',
      'move to assistance',
      'display assistance',
      'bring up assistance',
      'load assistance',
      'access assistance',
      'enter assistance',
    ],
    'back': [
      'go back',
      'back',
      'previous screen',
      'return',
      'go back to previous',
      'previous',
      'go back to last',
      'return to previous',
      'back to previous',
      'go back to last screen',
      'return to last',
      'back to last',
      'previous page',
      'last page',
      'go to previous',
      'go to last',
    ],
    'close': [
      'close',
      'exit',
      'quit',
      'close app',
      'exit app',
      'quit app',
      'close application',
      'exit application',
      'quit application',
      'close echo path',
      'exit echo path',
      'quit echo path',
    ],
    'help': [
      'what can i say',
      'available commands',
      'voice commands',
      'commands',
      'what commands',
      'show commands',
      'list commands',
      'available voice commands',
      'voice help',
      'command help',
      'navigation help',
      'voice assistance',
      'command assistance',
      'voice guide',
      'command guide',
      'help me',
      'i need help',
      'show help',
      'get help',
      'help with commands',
      'command assistance',
      'voice command help',
    ],
    'stop_listening': [
      'stop listening',
      'pause listening',
      'quiet mode',
      'mute voice',
      'stop voice recognition',
      'pause voice recognition',
      'mute voice recognition',
      'stop voice',
      'pause voice',
      'quiet voice',
      'silence voice',
      'turn off voice',
      'disable voice',
      'stop microphone',
      'pause microphone',
      'mute microphone',
    ],
    'start_listening': [
      'start listening',
      'resume listening',
      'listen again',
      'unmute voice',
      'start voice recognition',
      'resume voice recognition',
      'unmute voice recognition',
      'start voice',
      'resume voice',
      'unmute voice',
      'turn on voice',
      'enable voice',
      'start microphone',
      'resume microphone',
      'unmute microphone',
      'activate voice',
      'activate listening',
    ],
    'stop_speech': [
      'stop talking',
      'stop speaking',
      'stop narration',
      'stop audio',
      'stop voice',
      'stop guide',
      'stop tour',
      'quiet',
      'silence',
      'stop',
      'pause',
      'pause talking',
      'pause speaking',
      'pause narration',
      'pause audio',
      'pause voice',
      'pause guide',
      'pause tour',
      'be quiet',
      'shut up',
      'stop talking now',
      'stop speaking now',
      'stop narrating',
      'stop audio guide',
      'stop tour guide',
      'stop tour narration',
      'stop map narration',
      'stop location narration',
      'stop place narration',
      'stop facility narration',
      'stop attraction narration',
    ],
    'resume_speech': [
      'resume talking',
      'resume speaking',
      'resume narration',
      'resume audio',
      'resume voice',
      'resume guide',
      'resume tour',
      'continue talking',
      'continue speaking',
      'continue narration',
      'continue audio',
      'continue voice',
      'continue guide',
      'continue tour',
      'keep talking',
      'keep speaking',
      'keep narrating',
      'keep guiding',
      'keep touring',
      'go on',
      'continue',
      'resume',
      'start talking again',
      'start speaking again',
      'start narrating again',
      'start guiding again',
      'start touring again',
      'resume audio guide',
      'resume tour guide',
      'resume tour narration',
      'resume map narration',
      'resume location narration',
      'resume place narration',
      'resume facility narration',
      'resume attraction narration',
    ],
    'play_tour': [
      'play tour',
      'start tour',
      'play audio tour',
      'listen to tour',
      'play',
      'start playing',
      'begin tour',
      'play guided tour',
      'start guided tour',
      'begin guided tour',
      'play audio guide',
      'start audio guide',
      'begin audio guide',
      'play narration',
      'start narration',
      'begin narration',
      'play guide',
      'start guide',
      'begin guide',
    ],
    'stop_tour': [
      'stop tour',
      'stop playing',
      'pause tour',
      'end tour',
      'stop audio',
      'pause audio',
      'end audio',
      'stop guide',
      'pause guide',
      'end guide',
      'stop narration',
      'pause narration',
      'end narration',
      'stop audio guide',
      'pause audio guide',
      'end audio guide',
      'stop guided tour',
      'pause guided tour',
      'end guided tour',
    ],
    'download_all': [
      'download all',
      'download everything',
      'download available',
    ],
    // Home screen specific commands
    'home_welcome': [
      'welcome message',
      'say welcome',
      'greeting',
      'hello',
      'introduction',
      'app introduction',
      'tell me about the app',
      'what is this app',
      'app overview',
      'main features',
      'what can this app do',
      'app capabilities',
      'show features',
      'list features',
      'available features',
    ],
    'home_quick_access': [
      'quick access',
      'fast access',
      'quick navigation',
      'fast navigation',
      'quick menu',
      'fast menu',
      'quick options',
      'fast options',
      'quick commands',
      'fast commands',
      'shortcuts',
      'quick shortcuts',
      'fast shortcuts',
    ],
    'home_voice_settings': [
      'voice settings',
      'voice configuration',
      'voice options',
      'voice preferences',
      'voice setup',
      'voice control',
      'voice commands',
      'voice help',
      'voice assistance',
      'voice guide',
      'voice tutorial',
      'voice instructions',
    ],
    'home_status': [
      'home status',
      'app status',
      'system status',
      'current status',
      'what is happening',
      'what is active',
      'current state',
      'app state',
      'system state',
      'status report',
      'status update',
      'current information',
    ],
    'home_help': [
      'home help',
      'main help',
      'dashboard help',
      'home assistance',
      'main assistance',
      'dashboard assistance',
      'home guide',
      'main guide',
      'dashboard guide',
      'home tutorial',
      'main tutorial',
      'dashboard tutorial',
    ],
    // Discover screen specific commands
    'discover_find_tours': [
      'find tours',
      'discover tours',
      'show tours',
      'available tours',
      'nearby tours',
      'what tours',
      'find available tours',
      'list tours',
      'show available tours',
      'what tours are available',
      'find nearby tours',
      'discover available tours',
      'show nearby tours',
      'list available tours',
      'what tours can i take',
      'find tours near me',
      'show tours near me',
      'discover tours near me',
      'search tours',
      'browse tours',
      'explore tours',
    ],
    'discover_start_tour': [
      'start tour',
      'begin tour',
      'start audio tour',
      'begin audio tour',
      'start guided tour',
      'begin guided tour',
      'start audio guide',
      'begin audio guide',
      'start guide',
      'begin guide',
      'start narration',
      'begin narration',
      'start audio',
      'begin audio',
      'start playing',
      'begin playing',
      'play tour',
      'listen to tour',
      'play audio tour',
      'listen to audio tour',
    ],
    'discover_describe_tour': [
      'describe tour',
      'tell me about tour',
      'tour details',
      'tour information',
      'tour description',
      'tell about tour',
      'describe this tour',
      'tour overview',
      'tour summary',
      'tour facts',
      'tour info',
      'tell me more about tour',
      'tour details please',
      'describe the tour',
      'tour description please',
      'what is this tour',
      'tour explanation',
      'tour guide',
    ],
    'discover_tell_about_place': [
      'tell me about',
      'tell about',
      'describe',
      'what is',
      'tell me about this place',
      'describe this place',
      'what is this place',
      'tell about this place',
      'place information',
      'place details',
      'place description',
      'tell me about the place',
      'describe the place',
      'what is the place',
      'place overview',
      'place summary',
      'place facts',
      'place info',
      'place guide',
      'place explanation',
    ],
    'discover_refresh': [
      'refresh',
      'update',
      'refresh location',
      'update location',
      'refresh tours',
      'update tours',
      'find new tours',
      'search again',
      'look again',
      'check again',
      'refresh nearby',
      'update nearby',
      'refresh available',
      'update available',
    ],
    'discover_tour_discovery_mode': [
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
    'discover_place_exploration_mode': [
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
    'discover_detailed_info': [
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
    'discover_quick_info': [
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
    'discover_help': [
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
    // Downloads screen specific commands
    'downloads_play_tour': [
      'play tour',
      'start tour',
      'play audio tour',
      'listen to tour',
      'play',
      'start playing',
      'begin tour',
      'play guided tour',
      'start guided tour',
      'begin guided tour',
      'play audio guide',
      'start audio guide',
      'begin audio guide',
      'play narration',
      'start narration',
      'begin narration',
      'play guide',
      'start guide',
      'begin guide',
      'play downloaded tour',
      'start downloaded tour',
      'play saved tour',
      'start saved tour',
      'resume tour',
      'continue tour',
      'resume playing',
      'continue playing',
      'resume audio',
      'continue audio',
      'resume guide',
      'continue guide',
      'resume narration',
      'continue narration',
    ],
    'downloads_stop_tour': [
      'stop tour',
      'stop playing',
      'pause tour',
      'end tour',
      'stop audio',
      'pause audio',
      'end audio',
      'stop guide',
      'pause guide',
      'end guide',
      'stop narration',
      'pause narration',
      'end narration',
      'stop audio guide',
      'pause audio guide',
      'end audio guide',
      'stop guided tour',
      'pause guided tour',
      'end guided tour',
      'stop downloaded tour',
      'pause downloaded tour',
      'end downloaded tour',
    ],
    'downloads_pause_tour': [
      'pause tour',
      'pause playing',
      'pause audio',
      'pause guide',
      'pause narration',
      'pause audio guide',
      'pause guided tour',
      'pause downloaded tour',
      'pause saved tour',
      'hold tour',
      'hold playing',
      'hold audio',
      'hold guide',
      'hold narration',
      'suspend tour',
      'suspend playing',
      'suspend audio',
      'suspend guide',
      'suspend narration',
      'freeze tour',
      'freeze playing',
      'freeze audio',
      'freeze guide',
      'freeze narration',
    ],
    'downloads_download_all': [
      'download all',
      'download everything',
      'download available',
      'get all tours',
      'download all tours',
      'download all content',
      'get all content',
      'download everything available',
      'download all available',
      'get all available',
      'download all guides',
      'get all guides',
      'download all audio',
      'get all audio',
      'download all saved',
      'get all saved',
    ],
    'downloads_delete_downloads': [
      'delete downloads',
      'delete all',
      'remove downloads',
      'clear downloads',
      'delete all downloads',
      'remove all downloads',
      'clear all downloads',
      'delete downloaded content',
      'remove downloaded content',
      'clear downloaded content',
      'delete saved content',
      'remove saved content',
      'clear saved content',
      'delete offline content',
      'remove offline content',
      'clear offline content',
      'delete saved tours',
      'remove saved tours',
      'clear saved tours',
    ],
    'downloads_show_downloads': [
      'show downloads',
      'list downloads',
      'show saved',
      'list saved',
      'show offline',
      'list offline',
      'show downloaded content',
      'list downloaded content',
      'show saved content',
      'list saved content',
      'show offline content',
      'list offline content',
      'show my downloads',
      'list my downloads',
      'show downloaded tours',
      'list downloaded tours',
      'show saved tours',
      'list saved tours',
    ],
    'downloads_playback_control': [
      'next tour',
      'previous tour',
      'skip tour',
      'go to next',
      'go to previous',
      'next audio',
      'previous audio',
      'skip audio',
      'next guide',
      'previous guide',
      'skip guide',
      'next narration',
      'previous narration',
      'skip narration',
      'fast forward',
      'rewind',
      'go forward',
      'go back',
      'jump forward',
      'jump back',
      'seek forward',
      'seek back',
    ],
    'downloads_playback_status': [
      'what is playing',
      'what am i listening to',
      'current tour',
      'current audio',
      'current guide',
      'current narration',
      'playback status',
      'audio status',
      'tour status',
      'guide status',
      'narration status',
      'what tour is playing',
      'what audio is playing',
      'what guide is playing',
      'what narration is playing',
      'is anything playing',
      'is tour playing',
      'is audio playing',
      'is guide playing',
      'is narration playing',
    ],
    'downloads_volume_control': [
      'volume up',
      'volume down',
      'increase volume',
      'decrease volume',
      'mute',
      'unmute',
      'set volume',
      'adjust volume',
      'turn up volume',
      'turn down volume',
      'make it louder',
      'make it quieter',
      'volume maximum',
      'volume minimum',
      'volume full',
      'volume zero',
    ],
    'downloads_speed_control': [
      'speed up',
      'slow down',
      'increase speed',
      'decrease speed',
      'faster',
      'slower',
      'normal speed',
      'playback speed',
      'audio speed',
      'tour speed',
      'guide speed',
      'narration speed',
      'set speed',
      'adjust speed',
      'double speed',
      'half speed',
      'quarter speed',
    ],
    // Map screen specific commands
    'map_surroundings': [
      'tell me about my surroundings',
      'describe surroundings',
      'what is around me',
      'describe area',
      'tell me about this area',
      'what is here',
      'describe location',
      'tell me about location',
      'what is nearby',
      'describe nearby',
      'tell me about nearby',
      'what is around here',
      'describe this place',
      'tell me about this place',
      'what is this area',
      'describe current location',
      'tell me about current location',
      'what is my current location',
      'describe where i am',
      'tell me where i am',
    ],
    'map_great_places': [
      'what are the great places here',
      'great places',
      'best places',
      'top attractions',
      'must see places',
      'popular places',
      'famous places',
      'notable places',
      'important places',
      'key attractions',
      'main attractions',
      'primary attractions',
      'major attractions',
      'significant places',
      'landmark places',
      'tourist attractions',
      'visitor attractions',
      'sightseeing places',
      'points of interest',
      'places of interest',
    ],
    'map_facilities': [
      'what facilities are nearby',
      'facilities nearby',
      'nearby facilities',
      'local facilities',
      'available facilities',
      'what services are nearby',
      'services nearby',
      'nearby services',
      'local services',
      'available services',
      'what amenities are nearby',
      'amenities nearby',
      'nearby amenities',
      'local amenities',
      'available amenities',
      'what is available nearby',
      'available nearby',
      'what can i find nearby',
      'find nearby',
      'what is close by',
    ],
    'map_local_tips': [
      'give me local tips',
      'local tips',
      'travel tips',
      'visitor tips',
      'tourist tips',
      'local advice',
      'travel advice',
      'visitor advice',
      'tourist advice',
      'local recommendations',
      'travel recommendations',
      'visitor recommendations',
      'tourist recommendations',
      'local suggestions',
      'travel suggestions',
      'visitor suggestions',
      'tourist suggestions',
      'local guidance',
      'travel guidance',
      'visitor guidance',
    ],
    'map_zoom_control': [
      'zoom in',
      'zoom out',
      'increase zoom',
      'decrease zoom',
      'closer view',
      'farther view',
      'magnify',
      'reduce',
      'enlarge',
      'shrink',
      'expand view',
      'contract view',
      'wider view',
      'narrower view',
      'detailed view',
      'overview',
      'close up',
      'far away',
      'more detail',
      'less detail',
    ],
    'map_center': [
      'center map',
      'center on me',
      'center on location',
      'center on current location',
      'find my location',
      'locate me',
      'where am i',
      'show my location',
      'go to my location',
      'return to my location',
      'back to my location',
      'reset map',
      'reset view',
      'default view',
      'home position',
      'my position',
      'current position',
      'user location',
      'center on user',
      'focus on me',
    ],
    'map_navigation': [
      'start navigation to',
      'navigate to',
      'go to',
      'direct me to',
      'guide me to',
      'take me to',
      'lead me to',
      'route to',
      'path to',
      'way to',
      'direction to',
      'how to get to',
      'how do i get to',
      'route me to',
      'navigate me to',
      'guide me to',
      'show me the way to',
      'give me directions to',
      'provide directions to',
      'help me get to',
    ],
    'map_stop_navigation': [
      'stop navigation',
      'end navigation',
      'cancel navigation',
      'stop guiding',
      'end guiding',
      'cancel guiding',
      'stop directions',
      'end directions',
      'cancel directions',
      'stop route',
      'end route',
      'cancel route',
      'stop following',
      'end following',
      'cancel following',
      'stop tracking',
      'end tracking',
      'cancel tracking',
      'stop guidance',
      'end guidance',
    ],
    'downloads_help': [
      'downloads help',
      'offline help',
      'saved help',
      'downloads assistance',
      'offline assistance',
      'saved assistance',
      'downloads guide',
      'offline guide',
      'saved guide',
      'downloads tutorial',
      'offline tutorial',
      'saved tutorial',
      'downloads support',
      'offline support',
      'saved support',
    ],
    // Help screen specific commands
    'help_read_all_topics': [
      'read all topics',
      'read all',
      'hear all topics',
      'hear all',
      'list all topics',
      'list all',
      'show all topics',
      'show all',
      'tell me all topics',
      'tell me all',
      'read everything',
      'hear everything',
      'list everything',
      'show everything',
      'tell me everything',
      'all topics',
      'all commands',
      'read all commands',
      'hear all commands',
      'list all commands',
      'show all commands',
      'tell me all commands',
    ],
    'help_go_back': [
      'go back',
      'back',
      'return',
      'go back to previous',
      'return to previous',
      'go back to last',
      'return to last',
      'previous screen',
      'last screen',
      'go to previous',
      'return to previous screen',
      'go to last screen',
      'return to last screen',
      'navigate back',
      'navigate to previous',
      'navigate to last',
    ],
    'help_help': [
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
    ],
    'get_all_tours': [
      'get all tours',
      'download all tours',
      'download all content',
      'get all content',
      'download everything available',
      'download all available',
      'get all available',
      'download all guides',
      'get all guides',
      'download all audio',
      'get all audio',
    ],
    'delete_downloads': [
      'delete downloads',
      'delete all',
      'remove downloads',
      'clear downloads',
      'delete all downloads',
      'remove all downloads',
      'clear all downloads',
      'delete downloaded content',
      'remove downloaded content',
      'clear downloaded content',
      'delete saved content',
      'remove saved content',
      'clear saved content',
      'delete offline content',
      'remove offline content',
      'clear offline content',
    ],
    'find_tours': [
      'find tours',
      'discover tours',
      'show tours',
      'available tours',
      'nearby tours',
      'what tours',
      'find available tours',
      'list tours',
      'show available tours',
      'what tours are available',
      'find nearby tours',
      'discover available tours',
      'show nearby tours',
      'list available tours',
      'what tours can i take',
      'find tours near me',
      'show tours near me',
      'discover tours near me',
    ],
    'start_tour': [
      'start tour',
      'begin tour',
      'start audio tour',
      'begin audio tour',
      'start guided tour',
      'begin guided tour',
      'start audio guide',
      'begin audio guide',
      'start guide',
      'begin guide',
      'start narration',
      'begin narration',
      'start audio',
      'begin audio',
      'start playing',
      'begin playing',
    ],
    'describe_tour': [
      'describe tour',
      'tell me about tour',
      'tour details',
      'tour information',
      'tour description',
      'tell about tour',
      'describe this tour',
      'tour overview',
      'tour summary',
      'tour facts',
      'tour info',
      'tell me more about tour',
      'tour details please',
      'describe the tour',
      'tour description please',
    ],
    'tell_about_place': [
      'tell me about',
      'tell about',
      'describe',
      'what is',
      'tell me about this place',
      'describe this place',
      'what is this place',
      'tell about this place',
      'place information',
      'place details',
      'place description',
      'tell me about the place',
      'describe the place',
      'what is the place',
      'place overview',
      'place summary',
      'place facts',
      'place info',
    ],
  };

  // Map-specific command patterns
  static const Map<String, List<String>> _mapCommandPatterns = {
    'zoom_in': ['zoom in', 'closer', 'magnify', 'increase zoom'],
    'zoom_out': ['zoom out', 'farther', 'decrease zoom', 'wider view'],
    'center_map': [
      'center map',
      'show my location',
      'focus on me',
      'center on my position',
      'where am i',
    ],
    'nearby_attractions': [
      'nearby attractions',
      'what\'s nearby',
      'nearby places',
      'attractions',
      'what\'s around me',
      'show landmarks',
    ],
    'great_places': [
      'great places',
      'best places',
      'top attractions',
      'must visit',
      'recommended places',
      'tourist spots',
    ],
    'area_features': [
      'area features',
      'amenities',
      'facilities nearby',
      'what\'s available',
      'area amenities',
    ],
    'local_facilities': [
      'local facilities',
      'nearby facilities',
      'available facilities',
      'what facilities',
      'services nearby',
    ],
    'local_tips': [
      'local tips',
      'travel tips',
      'visitor tips',
      'useful tips',
      'advice for visitors',
    ],
    'local_events': [
      'local events',
      'events nearby',
      'what\'s happening',
      'activities',
      'current events',
    ],
    'weather_info': [
      'weather info',
      'weather conditions',
      'temperature',
      'weather status',
      'what\'s the weather',
    ],
    'describe_surroundings': [
      'describe surroundings',
      'what do i see',
      'describe area',
      'tell me about this place',
      'what\'s here',
      'tell me about my surroundings',
    ],
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
      print('VoiceNavigationService initialization error: $e');
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

  // Start continuous listening for navigation commands
  Future<void> startContinuousListening() async {
    if (!_isInitialized || _isListening) return;

    _isListening = true;
    _consecutiveErrors = 0;
    await _startListeningCycle();
    _voiceStatusController.add('listening_started');
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

  // Stop continuous listening
  Future<void> stopContinuousListening() async {
    _isListening = false;
    _listeningTimer?.cancel();
    _errorRecoveryTimer?.cancel();
    await _speech.stop();
    _voiceStatusController.add('listening_stopped');
  }

  // Handle speech recognition results with improved processing
  void _onSpeechResult(dynamic result) {
    if (result.finalResult) {
      final command = result.recognizedWords.toLowerCase().trim();
      print('Recognized command: "$command"');

      if (command.isNotEmpty) {
        _processNavigationCommand(command);
      }
    }
  }

  // Process navigation commands with improved matching and context awareness
  Future<void> _processNavigationCommand(String command) async {
    print('Processing navigation command: "$command"');

    // IMMEDIATELY stop any ongoing speech when user starts speaking
    await _stopCurrentSpeech();

    // Provide haptic feedback for command recognition
    await _provideHapticFeedback();

    // Check for stop/resume commands first (highest priority)
    if (_matchesPattern(command, _navigationPatterns['stop_speech']!)) {
      await _handleStopSpeech();
      return;
    }

    if (_matchesPattern(command, _navigationPatterns['resume_speech']!)) {
      await _handleResumeSpeech();
      return;
    }

    // Check for listening control commands
    if (_matchesPattern(command, _navigationPatterns['stop_listening']!)) {
      await _handleStopListening();
      return;
    }

    if (_matchesPattern(command, _navigationPatterns['start_listening']!)) {
      await _handleStartListening();
      return;
    }

    // Check for screen navigation commands with context awareness (prioritize navigation)
    for (final entry in _navigationPatterns.entries) {
      if (entry.key != 'help' &&
          entry.key != 'stop_listening' &&
          entry.key != 'start_listening' &&
          entry.key != 'stop_speech' &&
          entry.key != 'resume_speech') {
        if (_matchesPattern(command, entry.value)) {
          print(
            'Matched navigation command: ${entry.key} for command: "$command"',
          );
          await _executeNavigationCommand(entry.key, command);
          return;
        }
      }
    }

    // Check for help commands after navigation (to avoid conflicts)
    if (_matchesPattern(command, _navigationPatterns['help']!)) {
      print('Matched help command for: "$command"');
      await _provideContextAwareHelp();
      return;
    }

    // Check for map-specific commands
    for (final entry in _mapCommandPatterns.entries) {
      if (_matchesPattern(command, entry.value)) {
        await _executeMapCommand(entry.key, command);
        return;
      }
    }

    // Check for home-specific commands
    for (final entry in _navigationPatterns.entries) {
      if (entry.key.startsWith('home_')) {
        if (_matchesPattern(command, entry.value)) {
          await _executeHomeCommand(entry.key, command);
          return;
        }
      }
    }

    // Check for discover-specific commands
    for (final entry in _navigationPatterns.entries) {
      if (entry.key.startsWith('discover_')) {
        if (_matchesPattern(command, entry.value)) {
          await _executeDiscoverCommand(entry.key, command);
          return;
        }
      }
    }

    // Check for downloads-specific commands
    for (final entry in _navigationPatterns.entries) {
      if (entry.key.startsWith('downloads_')) {
        if (_matchesPattern(command, entry.value)) {
          await _executeDownloadsCommand(entry.key, command);
          return;
        }
      }
    }

    // Check for help-specific commands
    for (final entry in _navigationPatterns.entries) {
      if (entry.key.startsWith('help_')) {
        if (_matchesPattern(command, entry.value)) {
          await _executeHelpCommand(entry.key, command);
          return;
        }
      }
    }

    // Enhanced default response with context-aware suggestions
    await _provideContextAwareDefaultResponse();
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

  // Execute navigation commands with smooth transitions and context awareness
  Future<void> _executeNavigationCommand(
    String commandType,
    String fullCommand,
  ) async {
    try {
      String currentScreen = _transitionManager.currentScreen ?? 'home';
      print(
        'Executing navigation command: $commandType from $currentScreen to target screen',
      );

      switch (commandType) {
        case 'go_home':
          await _navigateToScreen('home', currentScreen);
          break;
        case 'go_map':
          await _navigateToScreen('map', currentScreen);
          break;
        case 'go_discover':
          await _navigateToScreen('discover', currentScreen);
          break;
        case 'go_downloads':
          await _navigateToScreen('downloads', currentScreen);
          break;
        case 'go_help':
          print('Navigating to help screen from $currentScreen');
          await _navigateToScreen('help', currentScreen);
          break;
        case 'back':
          await _navigateBack();
          break;
        case 'close':
          await _closeApp();
          break;
        case 'play_tour':
          await _handlePlayTour(fullCommand);
          break;
        case 'stop_tour':
          await _handleStopTour();
          break;
        case 'download_all':
          await _handleDownloadAll();
          break;
        case 'delete_downloads':
          await _handleDeleteDownloads();
          break;
        case 'find_tours':
          await _handleFindTours();
          break;
        case 'describe_tour':
          await _handleDescribeTour(fullCommand);
          break;
        case 'tell_about_place':
          await _handleTellAboutPlace(fullCommand);
          break;
        case 'start_tour':
          await _handleStartTour(fullCommand);
          break;
      }
    } catch (e) {
      print('Error executing navigation command: $e');
      await _provideErrorFeedback();
    }
  }

  // Handle play tour command
  Future<void> _handlePlayTour(String command) async {
    // Extract tour name from command
    String tourName = '';
    if (command.contains('play tour')) {
      tourName = command.split('play tour').last.trim();
    } else if (command.contains('start tour')) {
      tourName = command.split('start tour').last.trim();
    } else if (command.contains('listen to tour')) {
      tourName = command.split('listen to tour').last.trim();
    } else if (command.contains('play')) {
      tourName = command.split('play').last.trim();
    }

    if (tourName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Playing tour: $tourName",
        interrupt: true,
      );
      _navigationCommandController.add('play_tour:$tourName');
    } else {
      await _narrateForCurrentScreen(
        "Please specify which tour you want to play. Say 'play tour' followed by the tour name.",
        interrupt: true,
      );
    }
  }

  // Handle stop tour command
  Future<void> _handleStopTour() async {
    await _narrateForCurrentScreen("Stopping tour playback", interrupt: true);
    _navigationCommandController.add('stop_tour');
  }

  // Handle download all command
  Future<void> _handleDownloadAll() async {
    await _narrateForCurrentScreen(
      "Starting download of all available tours",
      interrupt: true,
    );
    _navigationCommandController.add('download_all');
  }

  // Handle delete downloads command
  Future<void> _handleDeleteDownloads() async {
    await _narrateForCurrentScreen(
      "Deleting all downloaded tours",
      interrupt: true,
    );
    _navigationCommandController.add('delete_downloads');
  }

  // Handle find tours command
  Future<void> _handleFindTours() async {
    await _narrateForCurrentScreen(
      "Finding available tours near your location",
      interrupt: true,
    );
    _navigationCommandController.add('find_tours');
  }

  // Handle describe tour command
  Future<void> _handleDescribeTour(String command) async {
    // Extract tour name from command
    String tourName = '';
    if (command.contains('describe tour')) {
      tourName = command.split('describe tour').last.trim();
    } else if (command.contains('tell me about tour')) {
      tourName = command.split('tell me about tour').last.trim();
    } else if (command.contains('tour details')) {
      tourName = command.split('tour details').last.trim();
    } else if (command.contains('tour information')) {
      tourName = command.split('tour information').last.trim();
    }

    if (tourName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Describing tour: $tourName",
        interrupt: true,
      );
      _navigationCommandController.add('describe_tour:$tourName');
    } else {
      await _narrateForCurrentScreen(
        "Please specify which tour you want me to describe. Say 'describe tour' followed by the tour name.",
        interrupt: true,
      );
    }
  }

  // Handle tell about place command
  Future<void> _handleTellAboutPlace(String command) async {
    // Extract place name from command
    String placeName = '';
    if (command.contains('tell me about')) {
      placeName = command.split('tell me about').last.trim();
    } else if (command.contains('tell about')) {
      placeName = command.split('tell about').last.trim();
    } else if (command.contains('describe')) {
      placeName = command.split('describe').last.trim();
    } else if (command.contains('what is')) {
      placeName = command.split('what is').last.trim();
    }

    if (placeName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Telling you about: $placeName",
        interrupt: true,
      );
      _navigationCommandController.add('tell_about_place:$placeName');
    } else {
      await _narrateForCurrentScreen(
        "Please specify which place you want me to tell you about. Say 'tell me about' followed by the place name.",
        interrupt: true,
      );
    }
  }

  // Handle start tour command
  Future<void> _handleStartTour(String command) async {
    // Extract tour name from command
    String tourName = '';
    if (command.contains('start tour')) {
      tourName = command.split('start tour').last.trim();
    } else if (command.contains('begin tour')) {
      tourName = command.split('begin tour').last.trim();
    } else if (command.contains('start audio tour')) {
      tourName = command.split('start audio tour').last.trim();
    } else if (command.contains('begin audio tour')) {
      tourName = command.split('begin audio tour').last.trim();
    }

    if (tourName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Starting tour: $tourName",
        interrupt: true,
      );
      _navigationCommandController.add('start_tour:$tourName');
    } else {
      await _narrateForCurrentScreen(
        "Please specify which tour you want to start. Say 'start tour' followed by the tour name.",
        interrupt: true,
      );
    }
  }

  // Execute map-specific commands
  Future<void> _executeMapCommand(
    String commandType,
    String fullCommand,
  ) async {
    try {
      switch (commandType) {
        case 'map_surroundings':
          await _handleMapSurroundings();
          break;
        case 'map_great_places':
          await _handleMapGreatPlaces();
          break;
        case 'map_facilities':
          await _handleMapFacilities();
          break;
        case 'map_local_tips':
          await _handleMapLocalTips();
          break;
        case 'map_zoom_control':
          await _handleMapZoomControl(fullCommand);
          break;
        case 'map_center':
          await _handleMapCenter();
          break;
        case 'map_navigation':
          await _handleMapNavigation(fullCommand);
          break;
        case 'map_stop_navigation':
          await _handleMapStopNavigation();
          break;
      }
    } catch (e) {
      print('Error executing map command: $e');
      await _provideErrorFeedback();
    }
  }

  // Execute home-specific commands
  Future<void> _executeHomeCommand(
    String commandType,
    String fullCommand,
  ) async {
    try {
      switch (commandType) {
        case 'home_welcome':
          await _handleHomeWelcome();
          break;
        case 'home_quick_access':
          await _handleHomeQuickAccess();
          break;
        case 'home_voice_settings':
          await _handleHomeVoiceSettings();
          break;
        case 'home_status':
          await _handleHomeStatus();
          break;
        case 'home_help':
          await _handleHomeHelp();
          break;
      }
    } catch (e) {
      print('Error executing home command: $e');
      await _provideErrorFeedback();
    }
  }

  // Execute discover-specific commands
  Future<void> _executeDiscoverCommand(
    String commandType,
    String fullCommand,
  ) async {
    try {
      switch (commandType) {
        case 'discover_find_tours':
          await _handleDiscoverFindTours();
          break;
        case 'discover_start_tour':
          await _handleDiscoverStartTour(fullCommand);
          break;
        case 'discover_describe_tour':
          await _handleDiscoverDescribeTour(fullCommand);
          break;
        case 'discover_tell_about_place':
          await _handleDiscoverTellAboutPlace(fullCommand);
          break;
        case 'discover_refresh':
          await _handleDiscoverRefresh();
          break;
        case 'discover_tour_discovery_mode':
          await _handleDiscoverTourDiscoveryMode();
          break;
        case 'discover_place_exploration_mode':
          await _handleDiscoverPlaceExplorationMode();
          break;
        case 'discover_detailed_info':
          await _handleDiscoverDetailedInfo();
          break;
        case 'discover_quick_info':
          await _handleDiscoverQuickInfo();
          break;
        case 'discover_help':
          await _handleDiscoverHelp();
          break;
      }
    } catch (e) {
      print('Error executing discover command: $e');
      await _provideErrorFeedback();
    }
  }

  // Execute downloads-specific commands
  Future<void> _executeDownloadsCommand(
    String commandType,
    String fullCommand,
  ) async {
    try {
      switch (commandType) {
        case 'downloads_play_tour':
          await _handleDownloadsPlayTour(fullCommand);
          break;
        case 'downloads_stop_tour':
          await _handleDownloadsStopTour();
          break;
        case 'downloads_pause_tour':
          await _handleDownloadsPauseTour();
          break;
        case 'downloads_download_all':
          await _handleDownloadsDownloadAll();
          break;
        case 'downloads_delete_downloads':
          await _handleDownloadsDeleteDownloads();
          break;
        case 'downloads_show_downloads':
          await _handleDownloadsShowDownloads();
          break;
        case 'downloads_playback_control':
          await _handleDownloadsPlaybackControl(fullCommand);
          break;
        case 'downloads_playback_status':
          await _handleDownloadsPlaybackStatus();
          break;
        case 'downloads_volume_control':
          await _handleDownloadsVolumeControl(fullCommand);
          break;
        case 'downloads_speed_control':
          await _handleDownloadsSpeedControl(fullCommand);
          break;
        case 'downloads_help':
          await _handleDownloadsHelp();
          break;
      }
    } catch (e) {
      print('Error executing downloads command: $e');
      await _provideErrorFeedback();
    }
  }

  // Execute help-specific commands
  Future<void> _executeHelpCommand(
    String commandType,
    String fullCommand,
  ) async {
    try {
      switch (commandType) {
        case 'help_read_all_topics':
          await _handleHelpReadAllTopics();
          break;
        case 'help_go_back':
          await _handleHelpGoBack();
          break;
        case 'help_help':
          await _handleHelpHelp();
          break;
      }
    } catch (e) {
      print('Error executing help command: $e');
      await _provideErrorFeedback();
    }
  }

  // Smooth navigation to screen with context awareness and seamless transitions
  Future<void> _navigateToScreen(String screen, String fromScreen) async {
    print('Navigating from $fromScreen to screen: $screen');

    // Provide immediate feedback for seamless experience
    String feedbackMessage = _getContextAwareNavigationFeedback(
      fromScreen,
      screen,
    );
    await _narrateForCurrentScreen(feedbackMessage, interrupt: true);

    // Use transition manager for smooth navigation with enhanced timing
    await _transitionManager.handleVoiceNavigation(screen);

    // Emit navigation event for UI updates
    _screenNavigationController.add(screen);
    _navigationCommandController.add('navigated:$screen');

    // Enhanced audio management for seamless transitions
    if (screen == 'discover') {
      // Ensure map audio is deactivated and discover audio is activated
      await _audioManager.deactivateScreenAudio('map');
      await Future.delayed(const Duration(milliseconds: 150));
      await _audioManager.activateScreenAudio('discover');
    } else if (screen == 'map') {
      // Ensure discover audio is deactivated and map audio is activated
      await _audioManager.deactivateScreenAudio('discover');
      await Future.delayed(const Duration(milliseconds: 150));
      await _audioManager.activateScreenAudio('map');
    } else if (screen == 'downloads') {
      // Ensure other screen audio is deactivated and downloads audio is activated
      await _audioManager.deactivateScreenAudio(fromScreen);
      await Future.delayed(const Duration(milliseconds: 150));
      await _audioManager.activateScreenAudio('downloads');
    } else if (screen == 'help') {
      // Ensure other screen audio is deactivated and help audio is activated
      await _audioManager.deactivateScreenAudio(fromScreen);
      await Future.delayed(const Duration(milliseconds: 150));
      await _audioManager.activateScreenAudio('help');
    } else if (screen == 'home') {
      // Ensure other screen audio is deactivated and home audio is activated
      await _audioManager.deactivateScreenAudio(fromScreen);
      await Future.delayed(const Duration(milliseconds: 150));
      await _audioManager.activateScreenAudio('home');
    }
  }

  // Navigate back
  Future<void> _navigateBack() async {
    await _tts.speak("Going back");
    _navigationCommandController.add('back');
  }

  // Close app
  Future<void> _closeApp() async {
    await _tts.speak("Closing EchoPath");
    _navigationCommandController.add('close');
  }

  // Provide context-aware help with available commands
  Future<void> _provideContextAwareHelp() async {
    String currentScreen = _transitionManager.currentScreen ?? 'home';
    String helpMessage = _getContextAwareHelpMessage(currentScreen);
    await _narrateForCurrentScreen(helpMessage, interrupt: true);
  }

  // Provide help with available commands
  Future<void> _provideHelp() async {
    String helpMessage = """
    Here are the available voice commands:
    
    Navigation: Say 'go to home', 'go to map', 'go to downloads', 'go to help', or 'go back'.
    
    Map features: Say 'tell me about my surroundings', 'what are the great places here', 'what facilities are nearby', or 'give me local tips'.
    
    Audio control: Say 'stop listening' to pause voice recognition, or 'start listening' to resume.
    
    For more specific help, navigate to the help screen.
    """;

    await _narrateForCurrentScreen(helpMessage, interrupt: true);
  }

  // Handle stop listening
  Future<void> _handleStopListening() async {
    await _narrateForCurrentScreen(
      "Voice recognition paused. Say 'start listening' to resume.",
      interrupt: true,
    );
    await stopContinuousListening();
  }

  // Handle start listening
  Future<void> _handleStartListening() async {
    await _narrateForCurrentScreen(
      "Voice recognition resumed.",
      interrupt: true,
    );
    await startContinuousListening();
  }

  // Provide default response with suggestions
  Future<void> _provideDefaultResponse() async {
    String response =
        "I didn't understand that command. Say 'help' for available commands, or try 'go to map' for navigation.";
    await _narrateForCurrentScreen(response, interrupt: true);
  }

  // Enhanced default response with context-aware suggestions
  Future<void> _provideContextAwareDefaultResponse() async {
    String currentScreen = _transitionManager.currentScreen ?? 'home';
    String response = _getContextAwareDefaultResponse(currentScreen);
    await _narrateForCurrentScreen(response, interrupt: true);
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

  // Get screen name for user feedback
  String _getScreenName(String screen) {
    switch (screen) {
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

  // Map command handlers
  Future<void> _handleZoomIn() async {
    await _narrateForCurrentScreen(
      "Zooming in for a closer view.",
      interrupt: true,
    );
    _mapCommandController.add('zoom_in');
  }

  Future<void> _handleZoomOut() async {
    await _narrateForCurrentScreen(
      "Zooming out for a wider view.",
      interrupt: true,
    );
    _mapCommandController.add('zoom_out');
  }

  Future<void> _handleCenterMap() async {
    await _narrateForCurrentScreen(
      "Centering the map on your current location.",
      interrupt: true,
    );
    _mapCommandController.add('center_map');
  }

  Future<void> _handleNearbyAttractions() async {
    await _narrateForCurrentScreen(
      "Searching for nearby attractions and landmarks.",
      interrupt: true,
    );
    _mapCommandController.add('nearby_attractions');
  }

  Future<void> _handleGreatPlaces() async {
    await _narrateForCurrentScreen(
      "I'll tell you about the great places to visit in this area.",
      interrupt: true,
    );
    _mapCommandController.add('great_places');
  }

  Future<void> _handleAreaFeatures() async {
    await _narrateForCurrentScreen(
      "I'll describe the features and amenities in this area.",
      interrupt: true,
    );
    _mapCommandController.add('area_features');
  }

  Future<void> _handleLocalFacilities() async {
    await _narrateForCurrentScreen(
      "I'll tell you about the facilities available in this area.",
      interrupt: true,
    );
    _mapCommandController.add('local_facilities');
  }

  Future<void> _handleLocalTips() async {
    await _narrateForCurrentScreen(
      "I'll share some local tips for your visit.",
      interrupt: true,
    );
    _mapCommandController.add('local_tips');
  }

  Future<void> _handleLocalEvents() async {
    await _narrateForCurrentScreen(
      "I'll tell you about local events and activities.",
      interrupt: true,
    );
    _mapCommandController.add('local_events');
  }

  Future<void> _handleWeatherInfo() async {
    await _narrateForCurrentScreen(
      "I'll get the current weather information for this area.",
      interrupt: true,
    );
    _mapCommandController.add('weather_info');
  }

  Future<void> _handleDescribeSurroundings() async {
    await _narrateForCurrentScreen(
      "I'll describe what you can see and experience in this area.",
      interrupt: true,
    );
    _mapCommandController.add('describe_surroundings');
  }

  // Get current listening status
  bool get isListening => _isListening;

  // Get initialization status
  bool get isInitialized => _isInitialized;

  // Context-aware navigation feedback
  String _getContextAwareNavigationFeedback(
    String fromScreen,
    String toScreen,
  ) {
    if (fromScreen == toScreen) {
      return "You're already on the ${_getScreenName(toScreen)}";
    }

    switch (toScreen) {
      case 'home':
        return "Navigating to the main dashboard. You can access all features from here.";
      case 'map':
        return "Opening the map screen. Voice guidance and location tracking are now active.";
      case 'discover':
        return "Taking you to the discover screen. Find tours and attractions with voice commands.";
      case 'downloads':
        return "Opening your downloads. Manage offline content and saved tours.";
      case 'help':
        return "Navigating to help and support. Get assistance with voice commands and features.";
      default:
        return "Navigating to ${_getScreenName(toScreen)}";
    }
  }

  // Context-aware help message
  String _getContextAwareHelpMessage(String currentScreen) {
    switch (currentScreen) {
      case 'home':
        return """
        From the home screen, you can say:
        'Go to map' for location tracking,
        'Go to discover' to find tours,
        'Go to downloads' for offline content,
        'Go to help' for assistance,
        or 'Help' anytime for commands.
        """;
      case 'map':
        return """
        From the map screen, you can say:
        'Go to home' to return to main menu,
        'Go to discover' to find tours,
        'Go to downloads' for offline content,
        'Go to help' for assistance,
        'Tell me about my surroundings' for area info,
        'What are the great places here' for attractions,
        or 'Help' for more commands.
        """;
      case 'discover':
        return """
        From the discover screen, you can say:
        'Go to home' to return to main menu,
        'Go to map' for location tracking,
        'Go to downloads' for offline content,
        'Go to help' for assistance,
        'Find tours' to search for available tours,
        'Start tour' followed by tour name,
        or 'Help' for more commands.
        """;
      case 'downloads':
        return """
        From the downloads screen, you can say:
        'Go to home' to return to main menu,
        'Go to map' for location tracking,
        'Go to discover' to find tours,
        'Go to help' for assistance,
        'Play tour' followed by tour name,
        'Download all' to get all available tours,
        'Delete downloads' to clear offline content,
        or 'Help' for more commands.
        """;
      case 'help':
        return """
        From the help screen, you can say:
        'Go to home' to return to main menu,
        'Go to map' for location tracking,
        'Go to discover' to find tours,
        'Go to downloads' for offline content,
        'Go back' to return to previous screen,
        or 'Help' to hear this message again.
        """;
      default:
        return """
        Available voice commands:
        Navigation: 'Go to home', 'Go to map', 'Go to discover', 'Go to downloads', 'Go to help', or 'Go back'.
        Audio control: 'Stop listening' to pause, 'Start listening' to resume.
        Say 'Help' anytime for available commands.
        """;
    }
  }

  // Context-aware default response
  String _getContextAwareDefaultResponse(String currentScreen) {
    switch (currentScreen) {
      case 'home':
        return "I didn't understand that command. From home, you can say 'go to map', 'go to discover', 'go to downloads', or 'go to help'. Say 'help' for all available commands.";
      case 'map':
        return "I didn't understand that command. From map, you can say 'go to home', 'go to discover', 'go to downloads', 'go to help', or 'tell me about my surroundings'. Say 'help' for all available commands.";
      case 'discover':
        return "I didn't understand that command. From discover, you can say 'go to home', 'go to map', 'go to downloads', 'go to help', or 'find tours'. Say 'help' for all available commands.";
      case 'downloads':
        return "I didn't understand that command. From downloads, you can say 'go to home', 'go to map', 'go to discover', 'go to help', or 'play tour'. Say 'help' for all available commands.";
      case 'help':
        return "I didn't understand that command. From help, you can say 'go to home', 'go to map', 'go to discover', 'go to downloads', or 'go back'. Say 'help' for all available commands.";
      default:
        return "I didn't understand that command. Say 'help' for available commands, or try 'go to map' for navigation.";
    }
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

  // Handle stop speech command
  Future<void> _handleStopSpeech() async {
    try {
      await _tts.stop();
      await _audioManager.stopAllAudio();
      await _narrateForCurrentScreen(
        "Stopped. I'm listening.",
        interrupt: true,
      );
      print('Speech stopped by user command');
    } catch (e) {
      print('Error handling stop speech: $e');
    }
  }

  // Handle resume speech command
  Future<void> _handleResumeSpeech() async {
    try {
      String currentScreen = _transitionManager.currentScreen ?? 'home';
      String message = _getContextAwareNavigationFeedback(
        currentScreen,
        currentScreen,
      );
      await _narrateForCurrentScreen("Resuming. $message", interrupt: true);
      print('Speech resumed by user command');
    } catch (e) {
      print('Error handling resume speech: $e');
    }
  }

  // Home command handlers
  Future<void> _handleHomeWelcome() async {
    await _narrateForCurrentScreen(
      "Welcome to EchoPath! Your voice-guided navigation companion. I'm here to help you explore the world around you with comprehensive audio guidance. You can navigate to different screens, discover tours, access offline content, and get help anytime. Say 'go to map' for location tracking, 'go to discover' for tours, 'go to downloads' for saved content, or 'go to help' for assistance. Each screen has its own voice commands for seamless interaction.",
      interrupt: true,
    );
    _homeCommandController.add('welcome');
  }

  Future<void> _handleHomeQuickAccess() async {
    await _narrateForCurrentScreen(
      "Quick access options: Say 'go to map' for location tracking and tour guide features, 'go to discover' to find and start tours, 'go to downloads' to access your saved offline content, or 'go to help' for assistance and voice command help. You can also say 'voice settings' to configure your voice preferences, 'status' to check current system status, or 'help' for comprehensive command list.",
      interrupt: true,
    );
    _homeCommandController.add('quick_access');
  }

  Future<void> _handleHomeVoiceSettings() async {
    await _narrateForCurrentScreen(
      "Voice settings available. You can say 'stop listening' to pause voice recognition, 'start listening' to resume, 'stop talking' to mute narration, 'resume talking' to continue narration. For navigation, say 'go to' followed by the screen name. Each screen has its own voice commands for enhanced interaction. Say 'help' anytime for available commands.",
      interrupt: true,
    );
    _homeCommandController.add('voice_settings');
  }

  Future<void> _handleHomeStatus() async {
    String status = """
    Current system status:
    Voice recognition: ${_isListening ? 'Active' : 'Inactive'}
    Current screen: ${_getScreenName(_transitionManager.currentScreen ?? 'home')}
    Navigation ready: ${_isInitialized ? 'Yes' : 'No'}
    Audio management: Active
    Screen transitions: Enabled
    
    Available features:
    - Voice-guided navigation between all screens
    - Location tracking and tour guide features
    - Tour discovery and audio tours
    - Offline content management
    - Comprehensive help and support
    """;

    await _narrateForCurrentScreen(status, interrupt: true);
    _homeCommandController.add('status');
  }

  Future<void> _handleHomeHelp() async {
    await _narrateForCurrentScreen(
      "Home screen help. You can say 'welcome message' for app introduction, 'quick access' for fast navigation options, 'voice settings' for voice configuration, 'status' for system information, or 'help' to hear this message again. For navigation, say 'go to' followed by map, discover, downloads, or help. Each screen has its own voice commands for seamless interaction.",
      interrupt: true,
    );
    _homeCommandController.add('help');
  }

  // Discover command handlers
  Future<void> _handleDiscoverFindTours() async {
    await _narrateForCurrentScreen(
      "I'll search for available tours near your location. Let me find the best tours and attractions for you to explore.",
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
    }

    if (tourName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Starting tour: $tourName. I'll guide you through this amazing experience.",
        interrupt: true,
      );
      _discoverCommandController.add('start_tour:$tourName');
    } else {
      await _narrateForCurrentScreen(
        "Please specify which tour you want to start. Say 'start tour' followed by the tour name.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDiscoverDescribeTour(String command) async {
    String tourName = '';
    if (command.contains('describe tour')) {
      tourName = command.split('describe tour').last.trim();
    } else if (command.contains('tell me about tour')) {
      tourName = command.split('tell me about tour').last.trim();
    } else if (command.contains('tour details')) {
      tourName = command.split('tour details').last.trim();
    }

    if (tourName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "I'll provide detailed information about the $tourName tour.",
        interrupt: true,
      );
      _discoverCommandController.add('describe_tour:$tourName');
    } else {
      await _narrateForCurrentScreen(
        "Please specify which tour you want to know about. Say 'describe tour' followed by the tour name.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDiscoverTellAboutPlace(String command) async {
    String placeName = '';
    if (command.contains('tell me about')) {
      placeName = command.split('tell me about').last.trim();
    } else if (command.contains('describe')) {
      placeName = command.split('describe').last.trim();
    } else if (command.contains('what is')) {
      placeName = command.split('what is').last.trim();
    }

    if (placeName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "I'll tell you about $placeName and what makes it special.",
        interrupt: true,
      );
      _discoverCommandController.add('tell_about_place:$placeName');
    } else {
      await _narrateForCurrentScreen(
        "Please specify which place you want to know about. Say 'tell me about' followed by the place name.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDiscoverRefresh() async {
    await _narrateForCurrentScreen(
      "Refreshing your location and searching for new tours and attractions nearby.",
      interrupt: true,
    );
    _discoverCommandController.add('refresh');
  }

  Future<void> _handleDiscoverTourDiscoveryMode() async {
    await _narrateForCurrentScreen(
      "Tour discovery mode activated. I'll help you find and explore the best tours available in your area.",
      interrupt: true,
    );
    _discoverCommandController.add('tour_discovery_mode');
  }

  Future<void> _handleDiscoverPlaceExplorationMode() async {
    await _narrateForCurrentScreen(
      "Place exploration mode activated. I'll provide detailed information about places and attractions in your area.",
      interrupt: true,
    );
    _discoverCommandController.add('place_exploration_mode');
  }

  Future<void> _handleDiscoverDetailedInfo() async {
    await _narrateForCurrentScreen(
      "Detailed information mode enabled. I'll provide comprehensive details about tours and places.",
      interrupt: true,
    );
    _discoverCommandController.add('detailed_info');
  }

  Future<void> _handleDiscoverQuickInfo() async {
    await _narrateForCurrentScreen(
      "Quick information mode enabled. I'll provide brief, essential information about tours and places.",
      interrupt: true,
    );
    _discoverCommandController.add('quick_info');
  }

  Future<void> _handleDiscoverHelp() async {
    await _narrateForCurrentScreen(
      "Discover screen help. You can say 'find tours' to search for available tours, 'start tour' followed by tour name to begin, 'describe tour' for detailed information, 'tell me about' followed by place name for place details, 'refresh' to update location, or 'help' to hear this message again. Each screen has its own voice commands for seamless interaction.",
      interrupt: true,
    );
    _discoverCommandController.add('help');
  }

  // Downloads command handlers
  Future<void> _handleDownloadsPlayTour(String command) async {
    String tourName = '';
    if (command.contains('play tour')) {
      tourName = command.split('play tour').last.trim();
    } else if (command.contains('start tour')) {
      tourName = command.split('start tour').last.trim();
    } else if (command.contains('listen to tour')) {
      tourName = command.split('listen to tour').last.trim();
    } else if (command.contains('play')) {
      tourName = command.split('play').last.trim();
    }

    if (tourName.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Playing downloaded tour: $tourName. Enjoy your audio guide.",
        interrupt: true,
      );
      _downloadsCommandController.add('play_tour:$tourName');
    } else {
      await _narrateForCurrentScreen(
        "Please specify which downloaded tour you want to play. Say 'play tour' followed by the tour name.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDownloadsStopTour() async {
    await _narrateForCurrentScreen(
      "Stopping tour playback. Audio guide paused.",
      interrupt: true,
    );
    _downloadsCommandController.add('stop_tour');
  }

  Future<void> _handleDownloadsDownloadAll() async {
    await _narrateForCurrentScreen(
      "Starting download of all available tours. This may take a few minutes.",
      interrupt: true,
    );
    _downloadsCommandController.add('download_all');
  }

  Future<void> _handleDownloadsDeleteDownloads() async {
    await _narrateForCurrentScreen(
      "Deleting all downloaded content. This will free up storage space.",
      interrupt: true,
    );
    _downloadsCommandController.add('delete_downloads');
  }

  Future<void> _handleDownloadsShowDownloads() async {
    await _narrateForCurrentScreen(
      "Showing your downloaded tours and saved content.",
      interrupt: true,
    );
    _downloadsCommandController.add('show_downloads');
  }

  Future<void> _handleDownloadsHelp() async {
    await _narrateForCurrentScreen(
      "Downloads screen help. You can say 'play tour' followed by tour name to start listening, 'pause tour' to pause, 'stop tour' to stop, 'resume tour' to continue, 'what is playing' for status, 'volume up/down' to adjust volume, 'speed up/down' to adjust speed, 'next/previous tour' to navigate, 'download all' to get all available tours, 'delete downloads' to clear offline content, 'show downloads' to list your saved content, or 'help' to hear this message again. Each screen has its own voice commands for seamless interaction.",
      interrupt: true,
    );
    _downloadsCommandController.add('help');
  }

  Future<void> _handleDownloadsPauseTour() async {
    await _narrateForCurrentScreen(
      "Tour playback paused. Say 'resume tour' to continue listening.",
      interrupt: true,
    );
    _downloadsCommandController.add('pause_tour');
  }

  Future<void> _handleDownloadsPlaybackControl(String command) async {
    String action = '';
    if (command.contains('next') ||
        command.contains('forward') ||
        command.contains('skip')) {
      action = 'next';
    } else if (command.contains('previous') ||
        command.contains('back') ||
        command.contains('rewind')) {
      action = 'previous';
    }

    if (action.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Moving to ${action == 'next' ? 'next' : 'previous'} tour.",
        interrupt: true,
      );
      _downloadsCommandController.add('playback_control:$action');
    } else {
      await _narrateForCurrentScreen(
        "Please specify 'next tour' or 'previous tour' for navigation.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDownloadsPlaybackStatus() async {
    await _narrateForCurrentScreen(
      "Checking current playback status.",
      interrupt: true,
    );
    _downloadsCommandController.add('playback_status');
  }

  Future<void> _handleDownloadsVolumeControl(String command) async {
    String action = '';
    if (command.contains('up') ||
        command.contains('increase') ||
        command.contains('louder')) {
      action = 'up';
    } else if (command.contains('down') ||
        command.contains('decrease') ||
        command.contains('quieter')) {
      action = 'down';
    } else if (command.contains('mute')) {
      action = 'mute';
    } else if (command.contains('unmute')) {
      action = 'unmute';
    }

    if (action.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Volume ${action == 'up'
            ? 'increased'
            : action == 'down'
            ? 'decreased'
            : action == 'mute'
            ? 'muted'
            : 'unmuted'}.",
        interrupt: true,
      );
      _downloadsCommandController.add('volume_control:$action');
    } else {
      await _narrateForCurrentScreen(
        "Please specify 'volume up', 'volume down', 'mute', or 'unmute'.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleDownloadsSpeedControl(String command) async {
    String action = '';
    if (command.contains('up') ||
        command.contains('increase') ||
        command.contains('faster')) {
      action = 'up';
    } else if (command.contains('down') ||
        command.contains('decrease') ||
        command.contains('slower')) {
      action = 'down';
    } else if (command.contains('normal')) {
      action = 'normal';
    }

    if (action.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Playback speed ${action == 'up'
            ? 'increased'
            : action == 'down'
            ? 'decreased'
            : 'set to normal'}.",
        interrupt: true,
      );
      _downloadsCommandController.add('speed_control:$action');
    } else {
      await _narrateForCurrentScreen(
        "Please specify 'speed up', 'speed down', or 'normal speed'.",
        interrupt: true,
      );
    }
  }

  // Help command handlers
  Future<void> _handleHelpReadAllTopics() async {
    await _narrateForCurrentScreen(
      "Reading all available voice commands. Voice Navigation: Say go to map, go to discover, go to downloads, go to help, or go back for seamless navigation. Map Commands: Say tell me about my surroundings, what are the great places here, what facilities are nearby, give me local tips, or zoom in/out. Tour Discovery: Say find tours to discover available tours, start tour followed by tour name to begin, or refresh to update location. Offline Downloads: Say play tour followed by tour name to start listening, stop tour to pause, download all to get available content, or delete downloads to free space. Audio Control: Say stop listening, start listening, pause voice, or resume voice. General Help: Say help, what can I say, or voice commands. Each screen's audio player becomes active when you visit it, with tone-adapted speech for better clarity across different accents.",
      interrupt: true,
    );
    _helpCommandController.add('read_all_topics');
  }

  Future<void> _handleHelpGoBack() async {
    await _narrateForCurrentScreen(
      "Returning to previous screen.",
      interrupt: true,
    );
    _helpCommandController.add('go_back');
  }

  Future<void> _handleHelpHelp() async {
    await _narrateForCurrentScreen(
      "Help and Support screen help. You can say 'read all topics' to hear all available voice commands, 'go back' to return to the previous screen, or 'help' to hear this message again. For navigation, say 'go to' followed by home, map, discover, or downloads.",
      interrupt: true,
    );
    _helpCommandController.add('help');
  }

  // Map command handlers
  Future<void> _handleMapSurroundings() async {
    await _narrateForCurrentScreen(
      "Describing your surroundings and current location.",
      interrupt: true,
    );
    _mapCommandController.add('surroundings');
  }

  Future<void> _handleMapGreatPlaces() async {
    await _narrateForCurrentScreen(
      "Telling you about the great places and attractions in this area.",
      interrupt: true,
    );
    _mapCommandController.add('great_places');
  }

  Future<void> _handleMapFacilities() async {
    await _narrateForCurrentScreen(
      "Describing nearby facilities and services available to you.",
      interrupt: true,
    );
    _mapCommandController.add('facilities');
  }

  Future<void> _handleMapLocalTips() async {
    await _narrateForCurrentScreen(
      "Providing local tips and travel advice for this area.",
      interrupt: true,
    );
    _mapCommandController.add('local_tips');
  }

  Future<void> _handleMapZoomControl(String command) async {
    String action = '';
    if (command.contains('in') ||
        command.contains('increase') ||
        command.contains('closer') ||
        command.contains('enlarge')) {
      action = 'in';
    } else if (command.contains('out') ||
        command.contains('decrease') ||
        command.contains('farther') ||
        command.contains('shrink')) {
      action = 'out';
    }

    if (action.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Zooming ${action == 'in' ? 'in' : 'out'} for ${action == 'in' ? 'closer' : 'wider'} view.",
        interrupt: true,
      );
      _mapCommandController.add('zoom_control:$action');
    } else {
      await _narrateForCurrentScreen(
        "Please specify 'zoom in' or 'zoom out' for map control.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleMapCenter() async {
    await _narrateForCurrentScreen(
      "Centering map on your current location.",
      interrupt: true,
    );
    _mapCommandController.add('center');
  }

  Future<void> _handleMapNavigation(String command) async {
    String destination = '';
    if (command.contains('navigate to')) {
      destination = command.split('navigate to').last.trim();
    } else if (command.contains('go to')) {
      destination = command.split('go to').last.trim();
    } else if (command.contains('take me to')) {
      destination = command.split('take me to').last.trim();
    }

    if (destination.isNotEmpty) {
      await _narrateForCurrentScreen(
        "Starting navigation to $destination. I'll guide you there with turn-by-turn directions.",
        interrupt: true,
      );
      _mapCommandController.add('navigation:$destination');
    } else {
      await _narrateForCurrentScreen(
        "Please specify a destination. Say 'navigate to' followed by the place name.",
        interrupt: true,
      );
    }
  }

  Future<void> _handleMapStopNavigation() async {
    await _narrateForCurrentScreen(
      "Stopping navigation. You can now explore freely.",
      interrupt: true,
    );
    _mapCommandController.add('stop_navigation');
  }

  // Dispose resources
  void dispose() {
    stopContinuousListening();
    _listeningTimer?.cancel();
    _continuousListeningTimer?.cancel();
    _errorRecoveryTimer?.cancel();
    _navigationCommandController.close();
    _screenNavigationController.close();
    _mapCommandController.close();
    _voiceStatusController.close();
  }
}
