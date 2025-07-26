import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'downloads_screen.dart';
//import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'tour_discovery_screen.dart';
import 'help_and_support_screen.dart';
import 'services/voice_navigation_service.dart';
import 'services/audio_manager_service.dart';
import 'services/screen_transition_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize voice navigation service
  final voiceNavigationService = VoiceNavigationService();
  await voiceNavigationService.initialize();

  // Initialize audio manager service
  final audioManagerService = AudioManagerService();
  await audioManagerService.initialize();

  // Initialize screen transition manager
  final screenTransitionManager = ScreenTransitionManager();
  await screenTransitionManager.initialize();

  // Start continuous voice listening for seamless navigation
  await voiceNavigationService.startContinuousListening();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/home': (context) => const HomeScreen(),
        '/downloads': (context) => const DownloadsScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/tourDiscovery': (context) => const TourDiscoveryScreen(),
        '/helpAndSupport': (context) => const HelpAndSupportScreen(),
      },
      title: 'Echo Guide',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late FlutterTts tts;
  late AnimationController _controller;
  late Animation<double> _animation;
  final VoiceNavigationService _voiceNavigationService =
      VoiceNavigationService();
  final AudioManagerService _audioManagerService = AudioManagerService();
  final ScreenTransitionManager _screenTransitionManager =
      ScreenTransitionManager();

  @override
  void initState() {
    super.initState();
    tts = FlutterTts();

    // Initialize animation
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _initTts();
    await _speakWelcome();

    // Navigate after the welcome message is complete
    await Future.delayed(const Duration(seconds: 10));
    _navigateToHome();
  }

  Future<void> _initTts() async {
    await tts.setLanguage("en-US");
    await tts.setPitch(1.0);
    await tts.setSpeechRate(0.5);
  }

  Future<void> _speakWelcome() async {
    await tts.speak(
      "Welcome to EchoPath. Your voice-powered journey begins now. I'll guide you through seamless voice navigation between all screens and provide comprehensive map assistance. You can navigate from any screen to any screen using voice commands. Only the active screen will have audio to ensure clear communication. Smooth transitions between screens are now enabled for a better user experience.",
    );
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    tts.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _animation,
                  child: const Icon(
                    Icons.mic,
                    color: Colors.blueAccent,
                    size: 100,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "EchoPath",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Voice powered tour guide",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.volume_up, color: Colors.blueAccent, size: 30),
                SizedBox(width: 10),
                Text(
                  "Initializing smooth navigation...",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
