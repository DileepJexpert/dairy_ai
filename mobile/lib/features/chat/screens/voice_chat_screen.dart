import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/chat/models/chat_models.dart';
import 'package:dairy_ai/features/chat/providers/chat_provider.dart';

/// Voice chat screen with microphone button, waveform animation,
/// language auto-detect display, and text transcript.
class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  bool _isRecording = false;
  bool _isProcessing = false;
  String _transcript = '';
  String _aiResponse = '';
  String _detectedLanguage = '';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _transcript = '';
      _aiResponse = '';
      _detectedLanguage = '';
    });
    _waveController.repeat();

    // TODO: Integrate Bhashini STT API here.
    // For now, simulate recording with a placeholder.
  }

  void _stopRecording() {
    _waveController.stop();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    // TODO: Replace with actual Bhashini STT call.
    // Simulate speech-to-text result after a short delay.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _transcript = 'Meri gaay ka doodh kam ho gaya hai';
        _detectedLanguage = 'Hindi';
        _isProcessing = false;
      });

      // Send the transcript as a chat message.
      ref.read(chatProvider.notifier).sendMessage(_transcript);

      // Listen for the AI response to display and play back.
      ref.listenManual<ChatState>(chatProvider, (prev, next) {
        if (!next.isSending &&
            next.messages.isNotEmpty &&
            next.messages.last.role == ChatRole.assistant) {
          if (mounted) {
            setState(() {
              _aiResponse = next.messages.last.content;
            });
            // TODO: Call Bhashini TTS to play back _aiResponse as audio.
          }
        }
      });
    });
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatState = ref.watch(chatProvider);
    final selectedLang = ChatLanguage.supported.firstWhere(
      (l) => l.code == chatState.selectedLanguage,
      orElse: () => ChatLanguage.supported.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Chat'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.language, color: Colors.white, size: 18),
            label: Text(
              selectedLang.nativeName,
              style: const TextStyle(color: Colors.white),
            ),
            onPressed: () => _showLanguagePicker(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Detected language display.
            if (_detectedLanguage.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: DairyTheme.lightGreen.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Detected: $_detectedLanguage',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Waveform animation.
            SizedBox(
              height: 80,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(280, 80),
                    painter: _WaveformPainter(
                      progress: _waveController.value,
                      isActive: _isRecording,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Microphone button.
            GestureDetector(
              onTap: _isProcessing ? null : _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isRecording ? 100 : 80,
                height: _isRecording ? 100 : 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? DairyTheme.errorRed
                      : DairyTheme.primaryGreen,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording
                              ? DairyTheme.errorRed
                              : DairyTheme.primaryGreen)
                          .withOpacity(0.4),
                      blurRadius: _isRecording ? 24 : 12,
                      spreadRadius: _isRecording ? 4 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Status text.
            Text(
              _isProcessing
                  ? 'Processing...'
                  : _isRecording
                      ? 'Listening... Tap to stop'
                      : 'Tap to speak',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: DairyTheme.subtleGrey,
              ),
            ),

            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),

            const Spacer(flex: 1),

            // Transcript section.
            if (_transcript.isNotEmpty || _aiResponse.isNotEmpty)
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_transcript.isNotEmpty) ...[
                          Text(
                            'You said:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: DairyTheme.subtleGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _transcript,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Divider(height: 20),
                        ],
                        if (chatState.isSending)
                          Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: DairyTheme.primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI is thinking...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: DairyTheme.subtleGrey,
                                ),
                              ),
                            ],
                          ),
                        if (_aiResponse.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.smart_toy_outlined,
                                size: 14,
                                color: DairyTheme.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'DairyAI:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: DairyTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              // TTS playback button (placeholder).
                              IconButton(
                                icon: const Icon(Icons.volume_up_outlined),
                                iconSize: 20,
                                color: DairyTheme.primaryGreen,
                                tooltip: 'Play response',
                                onPressed: () {
                                  // TODO: Trigger Bhashini TTS playback.
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'TTS playback coming soon (Bhashini)'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _aiResponse,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...ChatLanguage.supported.map((lang) {
                final isSelected =
                    lang.code == ref.read(chatProvider).selectedLanguage;
                return ListTile(
                  leading: isSelected
                      ? Icon(Icons.check_circle,
                          color: DairyTheme.primaryGreen)
                      : const Icon(Icons.circle_outlined),
                  title: Text(lang.nativeName),
                  subtitle: Text(lang.name),
                  onTap: () {
                    ref.read(chatProvider.notifier).setLanguage(lang.code);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Waveform painter for the voice recording animation.
// ---------------------------------------------------------------------------
class _WaveformPainter extends CustomPainter {
  final double progress;
  final bool isActive;

  _WaveformPainter({required this.progress, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive
          ? DairyTheme.primaryGreen.withOpacity(0.6)
          : DairyTheme.subtleGrey.withOpacity(0.3)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final barCount = 30;
    final barWidth = size.width / (barCount * 2);
    final centerY = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final x = (i * 2 + 1) * barWidth;
      final phase = progress * 2 * math.pi + (i * 0.3);
      final amplitude = isActive
          ? (size.height / 3) *
              (0.3 + 0.7 * math.sin(phase).abs()) *
              (0.5 + 0.5 * math.sin(i * 0.5 + progress * math.pi).abs())
          : size.height * 0.05;

      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isActive != isActive;
}
