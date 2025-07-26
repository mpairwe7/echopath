import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TourInstructionCard extends StatefulWidget {
  final VoidCallback? onVoiceHelp;
  final VoidCallback? onTouchHelp;

  const TourInstructionCard({super.key, this.onVoiceHelp, this.onTouchHelp});

  @override
  State<TourInstructionCard> createState() => _TourInstructionCardState();
}

class _TourInstructionCardState extends State<TourInstructionCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.purple.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "How to Use Tour Discovery",
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                          HapticFeedback.lightImpact();
                        },
                        icon: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState:
                      _isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                  firstChild: _buildQuickInstructions(),
                  secondChild: _buildDetailedInstructions(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInstructionRow(
            icon: Icons.mic,
            title: "Voice Commands",
            description:
                "Say 'find tours', 'start tour' plus name, 'describe tour' plus name",
            onTap: widget.onVoiceHelp,
          ),
          const SizedBox(height: 12),
          _buildInstructionRow(
            icon: Icons.touch_app,
            title: "Touch Controls",
            description: "Tap 'Find Tours', 'Start' buttons, or tour cards",
            onTap: widget.onTouchHelp,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Quick Tip: Say 'one' to start first tour, 'two' for second, etc.",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailedSection("🎤 Voice Commands", [
            "• 'find tours' - Search for tours",
            "• 'start tour' plus name - Begin tour",
            "• 'describe tour' plus name - Get details",
            "• 'tell me about' plus place - Learn about places",
            "• 'refresh' - Update location",
            "• 'list tours' - Hear all tours",
            "• 'help' - Get commands",
            "• 'one', 'two', 'three' - Quick start",
          ], Colors.blue),
          const SizedBox(height: 16),
          _buildDetailedSection("👆 Touch Controls", [
            "• Tap 'Find Tours' to search",
            "• Tap 'Refresh' to update",
            "• Tap 'Start' button next to tour",
            "• Tap tour cards for details",
            "• Swipe to browse tours",
            "• Long press for options",
          ], Colors.purple),
          const SizedBox(height: 16),
          _buildDetailedSection("📱 Quick Actions", [
            "• Say 'one' - Start first tour",
            "• Say 'two' - Start second tour",
            "• Say 'three' - Start third tour",
            "• Say 'four' - Start fourth tour",
            "• Double tap to start first tour",
            "• Swipe down to refresh",
          ], Colors.orange),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Available Tours",
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "• Say 'one' - Murchison Falls (2h, Easy, 4.8★)",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  "• Say 'two' - Kasubi Tombs (1.5h, Easy, 4.6★)",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  "• Say 'three' - Bwindi Forest (3h, Moderate, 4.9★)",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  "• Say 'four' - Lake Victoria (2.5h, Easy, 4.5★)",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedSection(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              item,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
