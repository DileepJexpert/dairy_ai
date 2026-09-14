import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../marketplace/widgets/store_design.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authProvider.notifier)
          .resetPassword(widget.token, _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You can now sign in.')),
      );
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reset password: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: storeCream,
        body: Column(
          children: [
            const StoreHeader(currentCategory: 'All'),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Icon(Icons.password,
                                  size: 42, color: storeGreen),
                              const SizedBox(height: 14),
                              const Text('Create a new password',
                                  textAlign: TextAlign.center,
                                  style: StoreType.heading),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _password,
                                obscureText: !_showPassword,
                                decoration: InputDecoration(
                                  labelText: 'New password',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                        () => _showPassword = !_showPassword),
                                    icon: Icon(_showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.length < 8
                                        ? 'Use at least 8 characters'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmation,
                                obscureText: !_showPassword,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm new password',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value != _password.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _saving || widget.token.isEmpty
                                    ? null
                                    : _save,
                                child: Text(
                                    _saving ? 'Updating…' : 'Update password'),
                              ),
                              if (widget.token.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'This reset link is incomplete. Request a new link from sign in.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: storeError),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
