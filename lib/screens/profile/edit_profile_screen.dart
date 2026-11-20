import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../core/tokens.dart';
import '../../widgets/widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();

  late String _selectedAvatar;
  String? _localError;

  final List<String> _avatarChoices = const ['A', 'D', 'M', 'R', 'S', '🌙', '⚡', '🛡️'];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().currentUser;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    _bioController.text = user?.bio ?? '';
    _selectedAvatar = user?.avatar.isNotEmpty == true ? user!.avatar : 'A';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _localError = 'Name cannot be empty.');
      return;
    }

    setState(() => _localError = null);
    context.read<AuthBloc>().add(AuthUpdateProfileRequested(
          name: name,
          email: _emailController.text.trim(),
          avatar: _selectedAvatar,
          bio: _bioController.text.trim(),
        ));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of Master DND?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.dnd.critical),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;

    return BlocConsumer<AuthBloc, AuthBlocState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
          Navigator.of(context).pop();
        } else if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error), backgroundColor: c.critical),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final user = context.read<AuthBloc>().currentUser;

        return Scaffold(
          backgroundColor: c.canvas,
          appBar: AppBar(
            backgroundColor: c.surface,
            elevation: 0,
            title: Text('Edit Profile', style: context.text.titleLarge),
            leading: IconButton(
              icon: Icon(Icons.close, color: c.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Space.s16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _handleSave,
                  child: Text(
                    'Save',
                    style: context.text.labelLarge!.copyWith(color: c.accent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(Space.s24),
              children: [
                // Avatar section
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: c.accentTint,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.accent, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _selectedAvatar,
                          style: context.text.displayLarge!.copyWith(
                            fontSize: 40,
                            color: c.accent,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit, size: 16, color: c.onAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.s16),
                const Center(child: OverlineText('Change Avatar')),
                const SizedBox(height: Space.s8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Space.s8,
                  children: _avatarChoices.map((av) {
                    final isSelected = av == _selectedAvatar;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatar = av),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: isSelected ? c.accent : c.surfaceAlt,
                        child: Text(
                          av,
                          style: TextStyle(
                            color: isSelected ? c.onAccent : c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: Space.s24),

                // Registered Phone (Read-Only)
                const OverlineText('Registered Phone Number'),
                const SizedBox(height: Space.s8),
                DndCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.phone_iphone, size: 20, color: c.textSecondary),
                        const SizedBox(width: Space.s12),
                        Expanded(
                          child: Text(
                            user?.phone ?? 'Not linked',
                            style: context.text.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.armed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 14, color: c.armed),
                              const SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: context.text.bodySmall!.copyWith(
                                  color: c.armed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.s16),

                // Full Name
                const OverlineText('Full Name'),
                const SizedBox(height: Space.s8),
                DndCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                    child: TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: context.text.titleMedium,
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s16),

                // Email Address
                const OverlineText('Email Address'),
                const SizedBox(height: Space.s8),
                DndCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: context.text.titleMedium,
                      decoration: const InputDecoration(
                        hintText: 'Enter email address',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s16),

                // Bio
                const OverlineText('Role / Status Note'),
                const SizedBox(height: Space.s8),
                DndCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                    child: TextField(
                      controller: _bioController,
                      style: context.text.titleMedium,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Focus time champion',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                if (_localError != null) ...[
                  const SizedBox(height: Space.s16),
                  Text(
                    _localError!,
                    style: context.text.bodySmall!.copyWith(color: c.critical),
                  ),
                ],

                const SizedBox(height: Space.s32),
                AppButton(
                  'Log Out',
                  type: AppButtonType.ghost,
                  onPressed: _confirmLogout,
                ),
                const SizedBox(height: Space.s16),
              ],
            ),
          ),
        );
      },
    );
  }
}
