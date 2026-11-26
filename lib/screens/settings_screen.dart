import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'auth_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  // Load custom key from SharedPreferences
  Future<void> _loadCustomApiKey() async {
    final key = await ref.read(themeNotifierProvider.notifier).getCustomApiKey();
    setState(() {
      _apiKeyController.text = key;
    });
  }

  // Save key
  Future<void> _saveCustomApiKey() async {
    await ref.read(themeNotifierProvider.notifier).setCustomApiKey(_apiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groq API Key saved successfully!'), backgroundColor: Colors.teal),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userDetails = ref.watch(userDetailsProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final themeNotifier = ref.read(themeNotifierProvider.notifier);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // User profile section card
            userDetails.when(
              data: (user) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'User Name',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? 'user@email.com',
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (err, stack) => const Text('Error loading user profile'),
            ),
            const SizedBox(height: 24),

            const Text(
              'App Customizations',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // Theme Mode Toggle Option
            Card(
              child: SwitchListTile(
                title: const Text('Dark Theme Mode'),
                subtitle: const Text('Switch between light and dark UI themes'),
                value: themeMode == ThemeMode.dark,
                onChanged: (val) => themeNotifier.toggleTheme(),
                secondary: const Icon(Icons.dark_mode_outlined),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'API CONFIGURATIONS (WHISPER AI)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            // Groq API Key Input Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        const Text(
                          'Groq API Key',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Groq Whisper provides exceptionally clear, exact, bilingual (Tamil + English) transcription refinement for audio recordings.',
                      style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to get a free API Key:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            '1. Visit console.groq.com/keys\n2. Create a free API Key\n3. Paste the key below and tap SAVE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apiKeyController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.apiKeyLabel ?? 'Enter Groq API Key',
                        hintText: AppLocalizations.of(context)?.apiKeyHint ?? 'Paste your API key here',
                        prefixIcon: const Icon(Icons.password_rounded),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveCustomApiKey,
                      child: const Text('SAVE API KEY'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Log Out Button
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('LOG OUT SESSION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.0),
                elevation: 0,
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Log Out'),
                    content: const Text('Are you sure you want to log out of your session?'),
                    actions: [
                      TextButton(
                        child: const Text('CANCEL'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: const Text('LOG OUT', style: TextStyle(color: Colors.redAccent)),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authNotifier.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
