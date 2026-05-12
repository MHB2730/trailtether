import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/runtime_config.dart';
import '../providers/auth_provider.dart' as ap;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _register = false;
  bool _obscure = true;
  String? _usernameError;
  bool _checkingUsername = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  // â”€â”€ Username uniqueness check â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<bool> _isUsernameAvailable(String username) async {
    if (!kSupabaseAvailable) return true;
    final result = await Supabase.instance.client.rpc(
      'is_username_available',
      params: {'p_username': username.toLowerCase()},
    );
    return result == true;
  }

  Future<void> _checkUsername(String raw) async {
    final username = raw.trim().toLowerCase();
    if (username.isEmpty) {
      setState(() => _usernameError = null);
      return;
    }
    if (username.length < 3) {
      setState(() => _usernameError = 'At least 3 characters');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(() => _usernameError = 'Letters, numbers and _ only');
      return;
    }
    setState(() {
      _checkingUsername = true;
      _usernameError = null;
    });
    final available = await _isUsernameAvailable(username);
    if (mounted) {
      setState(() {
        _checkingUsername = false;
        _usernameError = available ? null : 'Username already taken';
      });
    }
  }

  // â”€â”€ Persist username after registration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _saveUsername(String uid, String username) async {
    if (!kSupabaseAvailable) return;
    await Supabase.instance.client.from(kColProfiles).upsert({
      'id': uid,
      'username': username.toLowerCase(),
      'display_name': username,
    });
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (_register) {
      if (_usernameError != null) return;
      final username = _usernameCtrl.text.trim();
      if (username.length < 3) {
        setState(() => _usernameError = 'Username required (min 3 chars)');
        return;
      }
      final available = await _isUsernameAvailable(username);
      if (!mounted) return;
      if (!available) {
        setState(() => _usernameError = 'Username already taken');
        return;
      }
    }

    final auth = context.read<ap.AuthProvider>();
    final ok = _register
        ? await auth.registerEmail(
            _emailCtrl.text.trim(), _passCtrl.text, _usernameCtrl.text.trim())
        : await auth.signInEmail(_emailCtrl.text.trim(), _passCtrl.text);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Sign-in failed')),
      );
      return;
    }
    if (ok && _register && mounted) {
      final uid = auth.uid;
      if (uid != null) {
        await _saveUsername(uid, _usernameCtrl.text.trim());
      }
    }
  }

  Future<void> _submitGoogle() async {
    final auth = context.read<ap.AuthProvider>();
    final ok = await auth.signInWithGoogle();

    if (!ok && mounted) {
      if (auth.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Consumer<ap.AuthProvider>(
              builder: (_, auth, __) => Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/icon/hero_mountains.jpg',
                        width: 320,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Text(
                      'Trail Planner',
                      style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Mode toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _modeTab('Sign In', !_register),
                        const SizedBox(width: 8),
                        _modeTab('Create Account', _register),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Username â€” only on registration
                    if (_register) ...[
                      TextFormField(
                        controller: _usernameCtrl,
                        textInputAction: TextInputAction.next,
                        style: GoogleFonts.outfit(color: kColorCream),
                        decoration: _inputDeco('Username').copyWith(
                          suffixIcon: _checkingUsername
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                )
                              : _usernameError == null &&
                                      _usernameCtrl.text.length >= 3
                                  ? const Icon(Icons.check_circle,
                                      color: Color(0xFF4CAF50), size: 18)
                                  : null,
                          errorText: _usernameError,
                          helperText:
                              'Letters, numbers and _ only. Min 3 characters.',
                          helperStyle: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.3),
                              fontSize: 10),
                        ),
                        onChanged: _checkUsername,
                        validator: (v) {
                          if (!_register) return null;
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return 'Choose a username';
                          if (s.length < 3) return 'At least 3 characters';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(s)) {
                            return 'Letters, numbers and _ only';
                          }
                          return _usernameError;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Email
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.outfit(color: kColorCream),
                      decoration: _inputDeco('Email'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: GoogleFonts.outfit(color: kColorCream),
                      decoration: _inputDeco('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: kColorCream.withOpacity(0.4),
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your password';
                        }
                        if (_register && v.length < 6) {
                          return 'Minimum 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Primary button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: auth.busy ? null : _submitEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kColorOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: auth.busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_register ? 'Create Account' : 'Sign In',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle mode
                    GestureDetector(
                      onTap: () => setState(() {
                        _register = !_register;
                        _usernameError = null;
                        _usernameCtrl.clear();
                        _formKey.currentState?.reset();
                      }),
                      child: Text(
                        _register
                            ? 'Already have an account? Sign in'
                            : "Don't have an account? Create one",
                        style: GoogleFonts.outfit(
                            color: kColorOrange, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                            child:
                                Divider(color: kColorBorder.withOpacity(0.5))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR',
                              style: GoogleFonts.outfit(
                                  color: kColorCream.withOpacity(0.3),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                            child:
                                Divider(color: kColorBorder.withOpacity(0.5))),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Google button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: auth.busy ? null : _submitGoogle,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kColorBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          backgroundColor: kColorPanel,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.g_mobiledata,
                                color: kColorCream, size: 28),
                            const SizedBox(width: 8),
                            Text('Continue with Google',
                                style: GoogleFonts.outfit(
                                    color: kColorCream,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, bool active) => GestureDetector(
        onTap: () => setState(() {
          _register = label == 'Create Account';
          _usernameError = null;
          _usernameCtrl.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: active ? kColorOrange.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? kColorOrange : kColorBorder),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: active ? kColorOrange : kColorCream.withOpacity(0.5),
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
            color: kColorCream.withOpacity(0.3), fontSize: 14),
        filled: true,
        fillColor: kColorPanel,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kColorBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kColorOrange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 11),
      );
}
