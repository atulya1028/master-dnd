import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../core/tokens.dart';
import '../../widgets/widgets.dart';
import '../splash_screen.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();

  String _selectedAvatar = 'A';
  String? _localError;

  final List<String> _avatarChoices = const ['A', 'D', 'M', 'R', 'S', '🌙', '⚡', '🛡️'];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().currentUser;
    if (user != null) {
      if (user.name.isNotEmpty) {
        _nameController.text = user.name;
        _selectedAvatar = user.avatar;
      }
      if (user.email.isNotEmpty) {
        _emailController.text = user.email;
      }
      if (user.bio.isNotEmpty) {
        _bioController.text = user.bio;
      }
    }
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
      setState(() => _localError = 'Please enter your name.');
      return;
    }

    setState(() => _localError = null);
    context.read<AuthBloc>().add(AuthCompleteProfileRequested(
          name: name,
          email: _emailController.text.trim(),
          avatar: _selectedAvatar,
          bio: _bioController.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dnd;

    return BlocConsumer<AuthBloc, AuthBlocState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (route) => false,
          );
        } else if (state is AuthFailureState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error), backgroundColor: c.critical),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: c.canvas,
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: Space.s24, vertical: Space.s16),
              children: [
                Text('Step 2: Profile Setup', style: context.text.labelSmall),
                const SizedBox(height: Space.s12),
                Text('Set Up Your Profile', style: context.text.displayLarge),
                const SizedBox(height: Space.s8),
                Text(
                  'Personalize how Master DND greets you and organizes quiet hours.',
                  style: context.text.bodyMedium!.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.s24),

                // Avatar selector preview
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: c.accentTint,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.accent, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedAvatar,
                      style: context.text.displayLarge!.copyWith(color: c.accent),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s16),
                const Center(child: OverlineText('Choose an Avatar / Badge')),
                const SizedBox(height: Space.s8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Space.s12,
                  children: _avatarChoices.map((av) {
                    final isSelected = av == _selectedAvatar;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatar = av),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: isSelected ? c.accent : c.surfaceAlt,
                        child: Text(
                          av,
                          style: TextStyle(
                            color: isSelected ? c.onAccent : c.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: Space.s24),

                // Full Name
                const OverlineText('Full Name *'),
                const SizedBox(height: Space.s8),
                DndCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                    child: TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: context.text.titleMedium,
                      decoration: const InputDecoration(
                        hintText: 'e.g. John Doe',
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && _avatarChoices.contains(val[0].toUpperCase())) {
                          setState(() => _selectedAvatar = val[0].toUpperCase());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: Space.s16),

                // Email Address
                const OverlineText('Email Address (Optional)'),
                const SizedBox(height: Space.s8),
                DndCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: context.text.titleMedium,
                      decoration: const InputDecoration(
                        hintText: 'name@example.com',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.s16),

                // Bio or Occupation
                const OverlineText('Role / Bio (Optional)'),
                const SizedBox(height: Space.s8),
                DndCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.s16, vertical: 4),
                    child: TextField(
                      controller: _bioController,
                      style: context.text.titleMedium,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Software Engineer, Night Owl',
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
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  AppButton('Complete & Open Dashboard', onPressed: _handleSave),
                const SizedBox(height: Space.s24),
              ],
            ),
          ),
        );
      },
    );
  }
}
