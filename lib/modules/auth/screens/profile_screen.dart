import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/profile_repository.dart';
import '../../../shared_widgets/section_label.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = ProfileRepository();
  final _usernameController = TextEditingController();
  late Future<Profile> _profileFuture;
  bool _isSaving = false;
  String? _error;

  String get _userId => AuthService.currentUserId!;
  String get _email =>
      AuthService.currentSession?.user.email ?? 'Email unavailable';

  @override
  void initState() {
    super.initState();
    _profileFuture = _load();
  }

  Future<Profile> _load() async {
    final profile = await _repository.getOrCreateProfile(
      userId: _userId,
      fallbackUsername: 'Rider ${_userId.substring(0, 6)}',
    );
    _usernameController.text = profile.username;
    return profile;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _error = 'Username is required.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _repository.updateUsername(_userId, _usernameController.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<Profile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load profile: ${snapshot.error}'),
              ),
            );
          }

          final username = snapshot.data!.username;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                _ProfileHeader(username: username, email: _email),
                const SizedBox(height: 24),
                const SectionLabel('Account details'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Email',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_email),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        TextField(
                          controller: _usernameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
                const SizedBox(height: 28),
                const SectionLabel('Account'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Personal alerts'),
                    subtitle: const Text(
                      'Manage your saved station notifications',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.username, required this.email});

  final String username;
  final String email;

  @override
  Widget build(BuildContext context) {
    final initial = username.trim().isEmpty
        ? '?'
        : username.trim()[0].toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: AppColors.accent.withValues(alpha: .22),
          foregroundColor: AppColors.success,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(username, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
