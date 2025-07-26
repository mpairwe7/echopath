import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_navigation_service.dart';
import '../services/audio_manager_service.dart';

class VoiceCommandHelper extends StatefulWidget {
  final String currentScreen;
  final bool isListening;
  final VoidCallback? onVoiceToggle;

  const VoiceCommandHelper({
    super.key,
    required this.currentScreen,
    required this.isListening,
    this.onVoiceToggle,
  });

  @override
  State<VoiceCommandHelper> createState() => _VoiceCommandHelperState();
}

class _VoiceCommandHelperState extends State<VoiceCommandHelper>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  final VoiceNavigationService _voiceNavigationService =
      VoiceNavigationService();
  final AudioManagerService _audioManager = AudioManagerService();

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.easeOut));

    // Start animations if listening
    if (widget.isListening) {
      _startAnimations();
    }
  }

  @override
  void didUpdateWidget(VoiceCommandHelper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _startAnimations();
      } else {
        _stopAnimations();
      }
    }
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  void _stopAnimations() {
    _pulseController.stop();
    _waveController.stop();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Voice status indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: widget.isListening ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color:
                              widget.isListening ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                          boxShadow:
                              widget.isListening
                                  ? [
                                    BoxShadow(
                                      color: Colors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Icon(
                          widget.isListening ? Icons.mic : Icons.mic_off,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status text
            Text(
              widget.isListening
                  ? 'Listening for voice commands...'
                  : 'Voice commands disabled',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Current screen info
            Text(
              'Current screen: ${widget.currentScreen}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Voice command suggestions
            _buildVoiceSuggestions(),
            const SizedBox(height: 12),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Toggle voice button
                ElevatedButton.icon(
                  onPressed: widget.onVoiceToggle,
                  icon: Icon(widget.isListening ? Icons.mic_off : Icons.mic),
                  label: Text(
                    widget.isListening ? 'Stop Voice' : 'Start Voice',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        widget.isListening ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),

                // Help button
                ElevatedButton.icon(
                  onPressed: _showVoiceHelp,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSuggestions() {
    List<String> suggestions = _getSuggestionsForScreen(widget.currentScreen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Try saying:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              suggestions.map((suggestion) {
                return GestureDetector(
                  onTap: () => _speakSuggestion(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      suggestion,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  List<String> _getSuggestionsForScreen(String screen) {
    switch (screen.toLowerCase()) {
      case 'home':
        return ['one', 'two', 'three', 'four', 'help', 'welcome'];
      case 'map':
        return [
          'surroundings',
          'places',
          'facilities',
          'tips',
          'zoom in',
          'zoom out',
        ];
      case 'discover':
        return ['find tours', 'one', 'two', 'three', 'four', 'refresh'];
      case 'downloads':
        return [
          'one',
          'two',
          'three',
          'four',
          'pause',
          'stop',
          'next',
          'previous',
        ];
      case 'help':
        return [
          'one',
          'two',
          'three',
          'four',
          'five',
          'six',
          'read all',
          'back',
        ];
      default:
        return ['one', 'two', 'three', 'four', 'help'];
    }
  }

  void _speakSuggestion(String suggestion) async {
    // Provide haptic feedback
    HapticFeedback.lightImpact();

    // Speak the suggestion
    await _audioManager.speakIfActive(
      widget.currentScreen,
      "Try saying: $suggestion",
    );
  }

  void _showVoiceHelp() async {
    // Provide haptic feedback
    HapticFeedback.mediumImpact();

    // Show help dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Voice Commands'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Navigation:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• "one" - Go to map'),
                  const Text('• "two" - Go to tours'),
                  const Text('• "three" - Go to downloads'),
                  const Text('• "four" - Go to help'),
                  const SizedBox(height: 16),
                  const Text(
                    'Tour Discovery:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• "find tours" - Search for tours'),
                  const Text('• "one", "two", "three", "four" - Start tours'),
                  const Text('• "refresh" - Update location'),
                  const SizedBox(height: 16),
                  const Text(
                    'Downloads:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• "one", "two", "three", "four" - Play tours'),
                  const Text('• "pause" - Pause playback'),
                  const Text('• "stop" - Stop playback'),
                  const Text('• "next" - Next tour'),
                  const Text('• "previous" - Previous tour'),
                  const SizedBox(height: 16),
                  const Text(
                    'Help:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• "one" through "six" - Topic help'),
                  const Text('• "read all" - All commands'),
                  const Text('• "back" - Go back'),
                  const SizedBox(height: 16),
                  const Text(
                    'General:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• "help" - Get help'),
                  const Text('• "stop" - Stop current action'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
