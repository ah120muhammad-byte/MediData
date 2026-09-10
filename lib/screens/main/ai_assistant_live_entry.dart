import 'package:flutter/material.dart';

import 'ai_assistant_screen.dart';
import 'ai_live_screen.dart';

/// Hosts the normal AI chat and provides a responsive entry point to
/// Gemini Live without changing the existing chat implementation.
class AiAssistantLiveEntry extends StatelessWidget {
  const AiAssistantLiveEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 420;

    return Stack(
      fit: StackFit.expand,
      children: [
        const AiAssistantScreen(),
        Positioned(
          top: compact ? 70 : 74,
          right: compact ? 12 : 18,
          child: SafeArea(
            top: false,
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Talk to MediData AI',
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AiLiveScreen(mode: 'smart'),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.graphic_eq_rounded,
                    size: compact ? 18 : 19,
                  ),
                  label: Text(
                    compact ? 'Live' : 'Live AI',
                    style: TextStyle(fontSize: compact ? 12 : 13),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 8 : 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
