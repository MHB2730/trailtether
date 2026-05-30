import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design_tokens.dart';
import '../services/auth_service.dart';

/// Landing screen after the user opens a password-recovery email link.
///
/// AuthGate routes here when Supabase fires `AuthChangeEvent.passwordRecovery`,
/// which happens after `DeepLinkService` hands the recovery URL to
/// `auth.getSessionFromUrl`. The user is now in a short-lived recovery
/// session — they MUST set a new password before the regular shell can
/// take over. Submit → `auth.updateUser(password)` → AuthGate sees the
/// flag clear and routes to the normal shell.
class SetNewPasswordScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const SetNewPasswordScreen({super.key, required this.onCompleted});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _showPass = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.updatePassword(_passCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
      widget.onCompleted();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.friendlyError(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update password: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset, color: TT.ember, size: 44),
                    const SizedBox(height: TT.s4),
                    Text('Set a new password', style: TT.title(22)),
                    const SizedBox(height: TT.s2),
                    Text(
                      'You opened a password-reset link. Choose a new password — we\'ll sign you in afterwards.',
                      style: TT.body(size: 13, color: TT.text2),
                    ),
                    const SizedBox(height: TT.s5),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: !_showPass,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          icon: Icon(_showPass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass),
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.length < 8) return 'At least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: TT.s3),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: !_showPass,
                      decoration:
                          const InputDecoration(labelText: 'Confirm password'),
                      validator: (v) {
                        if ((v ?? '') != _passCtrl.text) {
                          return 'Passwords don\'t match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: TT.s5),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save new password'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
