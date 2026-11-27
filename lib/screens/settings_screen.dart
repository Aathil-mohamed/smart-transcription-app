import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_design_tokens.dart';
import '../core/theme/motion_helpers.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/secrets_service.dart';
import 'auth_screen.dart';
import 'debug_audio_spike_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _groqApiKeyController = TextEditingController();
  final _geminiApiKeyController = TextEditingController();

  bool _hideGroqKey = true;
  bool _hideGeminiKey = true;
  int _secretTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  @override
  void dispose() {
    _groqApiKeyController.dispose();
    _geminiApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKeys() async {
    final secrets = ref.read(secretsServiceProvider);
    final groqKey = await secrets.getGroqApiKey();
    final geminiKey = await secrets.getGeminiApiKey();
    if (mounted) {
      setState(() {
        _groqApiKeyController.text = groqKey ?? '';
        _geminiApiKeyController.text = geminiKey ?? '';
      });
    }
  }

  Future<void> _saveGroqApiKey() async {
    await ref
        .read(secretsServiceProvider)
        .setGroqApiKey(_groqApiKeyController.text.trim());
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Groq Whisper API Key saved securely!'),
          backgroundColor: Palette.emerald,
        ),
      );
    }
  }

  Future<void> _saveGeminiApiKey() async {
    await ref
        .read(secretsServiceProvider)
        .setGeminiApiKey(_geminiApiKeyController.text.trim());
    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemini Fallback API Key saved securely!'),
          backgroundColor: Palette.emerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userDetails = ref.watch(userDetailsProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final themeNotifier = ref.read(themeNotifierProvider.notifier);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    final user = userDetails.value;
    final displayName =
        user?.name.isNotEmpty == true ? user!.name : 'Studio User';
    final userEmail = user?.email ?? 'user@smarttranscribe.app';
    final initialLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
          children: [
            // Top Back Navigation
            Row(
              children: [
                Tactile(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _secretTapCount++;
                if (_secretTapCount >= 5) {
                  _secretTapCount = 0;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DebugAudioSpikeScreen(),
                    ),
                  );
                }
              },
              child: const Text(
                'Settings',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 20),

            // Emerald Profile Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Palette.emerald,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: Text(
                      initialLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userEmail,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dark Mode Row with Sun/Moon Animation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (c, a) =>
                            RotationTransition(turns: a, child: c),
                        child: Icon(
                          isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          key: ValueKey(isDark),
                          color: isDark ? Palette.amber : Palette.coral,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dark Theme Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Switch between paper & charcoal',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: themeMode == ThemeMode.dark,
                    activeThumbColor: Palette.coral,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      themeNotifier.setThemeMode(
                          v ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Terminal-Styled Groq Whisper API Key Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Palette.charcoalCard : Palette.ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: Palette.amber, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Groq Whisper AI Key',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Powers bilingual Tamil + English Whisper-large-v3 refinement.\nGet your free key at console.groq.com/keys',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _groqApiKeyController,
                    obscureText: _hideGroqKey,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      hintText: 'Paste gsk_... key here',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hideGroqKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () =>
                            setState(() => _hideGroqKey = !_hideGroqKey),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Tactile(
                    onTap: _saveGroqApiKey,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Palette.coral,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Center(
                        child: Text(
                          'Save Groq API Key',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Terminal-Styled Gemini Fallback Key Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Palette.charcoalCard : Palette.ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: Palette.coral, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Google Gemini Fallback Key',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Optional fallback provider (gemini-2.5-flash) if Groq is unavailable.\nGet your key at aistudio.google.com',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _geminiApiKeyController,
                    obscureText: _hideGeminiKey,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      hintText: 'Paste AIza... key here',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _hideGeminiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () =>
                            setState(() => _hideGeminiKey = !_hideGeminiKey),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Tactile(
                    onTap: _saveGeminiApiKey,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Palette.coral,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Center(
                        child: Text(
                          'Save Gemini API Key',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Debug-only Audio & STT Spike Test Card
            if (kDebugMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Palette.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Palette.emerald.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bug_report_rounded, color: Palette.emerald, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Audio Concurrency Spike',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Palette.emerald,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '30s test: PCM stream + SpeechToText simultaneous',
                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.emerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DebugAudioSpikeScreen(),
                          ),
                        );
                      },
                      child: const Text('OPEN'),
                    ),
                  ],
                ),
              ),
            ],

            // Log Out Session Button
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      title: const Text('Log Out Session?',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      content: const Text(
                          'Are you sure you want to log out of your account on this device?'),
                      actions: [
                        TextButton(
                          child: const Text('CANCEL',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          child: const Text('LOG OUT',
                              style: TextStyle(
                                  color: Palette.coral,
                                  fontWeight: FontWeight.w700)),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await authNotifier.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        SlideUpRoute(builder: (_) => const AuthScreen()),
                        (_) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Palette.coral),
                label: const Text(
                  'Log Out Session',
                  style: TextStyle(
                    color: Palette.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
