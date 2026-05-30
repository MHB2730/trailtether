// Trailtether v3.0 — Login screen.
//
// Reskin onto the TT design system: TT.bg backdrop, TTAmbient + TTTopoBackdrop
// layers, TTBrandMark header, hero photo, a TTCard form with a TTSegmented
// Sign In / Create Account toggle, TT-styled inputs, an ember pill primary
// button and an outline "Continue with Google" button. Behaviour is identical
// to the prior screen: email/password sign-in & register via AuthProvider,
// username uniqueness check on register, password reveal toggle, Google
// sign-in, and a "Forgot password?" dialog that calls
// `Supabase.instance.client.auth.resetPasswordForEmail`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../core/runtime_config.dart';
import '../providers/auth_provider.dart' as ap;
import '../services/auth_service.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_segmented.dart';
import '../widgets/design/tt_topo.dart';

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
  // Track email value so "Forgot password?" can enable only when non-empty.
  String _emailValue = '';

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(() {
      if (mounted && _emailCtrl.text != _emailValue) {
        setState(() => _emailValue = _emailCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  // ── Username uniqueness check ──────────────────────────────────────────────
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

  // ── Persist username after registration ────────────────────────────────────
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
      // Error pill above the primary button already surfaces auth.error live;
      // keep the snackbar fallback for cases where the error gets cleared
      // before the user can read it.
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

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email above first')),
      );
      return;
    }
    // Confirm before firing the reset email.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(email: email),
    );
    if (confirmed != true || !mounted) return;
    if (!kSupabaseAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset unavailable offline')),
      );
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset email sent to $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset email: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.5)),
          SafeArea(
            child: Consumer<ap.AuthProvider>(
              builder: (_, auth, __) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand row — matches TTPageAppBar styling without the
                    // large page title (login is a focused screen).
                    const Padding(
                      padding: EdgeInsets.fromLTRB(0, 4, 0, 14),
                      child: Row(children: [TTBrandMark()]),
                    ),
                    // Hero image — kept from the legacy login but framed in
                    // the new card radius and given a soft graphite gradient
                    // to settle it into the dark backdrop.
                    _HeroPanel(),
                    const SizedBox(height: TT.s5),
                    // Form card
                    TTCard(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TTSegmented(
                              tabs: const ['Sign In', 'Create Account'],
                              active: _register ? 1 : 0,
                              onChange: (i) => setState(() {
                                _register = i == 1;
                                _usernameError = null;
                                _usernameCtrl.clear();
                                _formKey.currentState?.reset();
                              }),
                            ),
                            const SizedBox(height: TT.s5),
                            // Username — only on Create Account
                            if (_register) ...[
                              _LabeledField(
                                label: 'USERNAME',
                                child: TextFormField(
                                  controller: _usernameCtrl,
                                  textInputAction: TextInputAction.next,
                                  style: TT.body(size: 14, color: TT.text),
                                  cursorColor: TT.ember,
                                  decoration: _ttDeco('hiker_handle').copyWith(
                                    suffixIcon: _checkingUsername
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: TT.ember,
                                              ),
                                            ),
                                          )
                                        : _usernameError == null &&
                                                _usernameCtrl.text.length >= 3
                                            ? const Icon(
                                                Icons.check_circle,
                                                color: TT.green,
                                                size: 18,
                                              )
                                            : null,
                                    errorText: _usernameError,
                                    helperText:
                                        'Letters, numbers and _ only. Min 3 characters.',
                                    helperStyle: TT.mono(
                                      size: 10,
                                      color: TT.text3,
                                      w: FontWeight.w600,
                                    ),
                                  ),
                                  onChanged: _checkUsername,
                                  validator: (v) {
                                    if (!_register) return null;
                                    final s = v?.trim() ?? '';
                                    if (s.isEmpty) return 'Choose a username';
                                    if (s.length < 3) {
                                      return 'At least 3 characters';
                                    }
                                    if (!RegExp(r'^[a-zA-Z0-9_]+$')
                                        .hasMatch(s)) {
                                      return 'Letters, numbers and _ only';
                                    }
                                    return _usernameError;
                                  },
                                ),
                              ),
                              const SizedBox(height: TT.s3),
                            ],
                            _LabeledField(
                              label: 'EMAIL',
                              child: TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                style: TT.body(size: 14, color: TT.text),
                                cursorColor: TT.ember,
                                autocorrect: false,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(
                                      RegExp(r'\s')),
                                ],
                                decoration: _ttDeco('you@trail.run'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter your email';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: TT.s3),
                            _LabeledField(
                              label: 'PASSWORD',
                              child: TextFormField(
                                controller: _passCtrl,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                style: TT.body(size: 14, color: TT.text),
                                cursorColor: TT.ember,
                                decoration: _ttDeco('••••••••').copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: TT.text3,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    tooltip: _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                  ),
                                ),
                                onFieldSubmitted: (_) {
                                  if (!auth.busy) _submitEmail();
                                },
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
                            ),
                            const SizedBox(height: TT.s2),
                            // Forgot password — Sign In tab only, only when
                            // an email is typed. Aligned right under the
                            // password field where it lives in most apps.
                            if (!_register)
                              Align(
                                alignment: Alignment.centerRight,
                                child: _LinkText(
                                  label: 'Forgot password?',
                                  enabled: _emailValue.trim().isNotEmpty,
                                  onTap: _forgotPassword,
                                ),
                              ),
                            // Error pill — surfaces AuthProvider.error so the
                            // user sees what went wrong without dismissing
                            // the screen. Hidden when null.
                            if (auth.error != null) ...[
                              const SizedBox(height: TT.s3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: TTPill(
                                        label: _shortError(auth.error!),
                                        variant: TTPillVariant.danger,
                                        leadingIcon: Icons.error_outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: TT.s4),
                            // Primary action — ember pill button
                            _EmberButton(
                              label: _register ? 'Create account' : 'Sign in',
                              loading: auth.busy,
                              onPressed: auth.busy ? null : _submitEmail,
                            ),
                            const SizedBox(height: TT.s3),
                            Center(
                              child: _LinkText(
                                label: _register
                                    ? 'Already have an account? Sign in'
                                    : "Don't have an account? Create one",
                                onTap: () => setState(() {
                                  _register = !_register;
                                  _usernameError = null;
                                  _usernameCtrl.clear();
                                  _formKey.currentState?.reset();
                                }),
                              ),
                            ),
                            const SizedBox(height: TT.s5),
                            // OR divider
                            const _OrDivider(),
                            const SizedBox(height: TT.s5),
                            // Google button — outline style
                            _GoogleButton(
                              loading: auth.busy,
                              onPressed: auth.busy ? null : _submitGoogle,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: TT.s5),
                    // Footer micro-copy
                    Center(
                      child: Text(
                        'FREE  ·  NO ADS',
                        textAlign: TextAlign.center,
                        style: TT.mono(
                          size: 9.5,
                          color: TT.text4,
                          w: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: TT.s2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Auth errors can be long. Pills look best with a short uppercase label,
  // so trim to the first sentence and cap at ~40 chars.
  static String _shortError(String e) {
    final s = e.replaceAll('\n', ' ').trim();
    final first = s.split('. ').first;
    final trimmed = first.length > 40 ? '${first.substring(0, 37)}…' : first;
    return trimmed.toUpperCase();
  }

  /// Shared input decoration matching TT inputs: surf fill, hairline border,
  /// ember focus, mono error text.
  InputDecoration _ttDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TT.body(size: 14, color: TT.text3, w: FontWeight.w500),
        filled: true,
        fillColor: TT.surf,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TT.rMd),
          borderSide: const BorderSide(color: TT.line2, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TT.rMd),
          borderSide: const BorderSide(color: TT.ember, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TT.rMd),
          borderSide: const BorderSide(color: TT.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TT.rMd),
          borderSide: const BorderSide(color: TT.red, width: 1.5),
        ),
        errorStyle: TT.mono(size: 10.5, color: TT.red, w: FontWeight.w700),
      );
}

// ─── Hero panel ──────────────────────────────────────────────────────────────

class _HeroPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TT.rLg),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: TT.line, width: 1),
          borderRadius: BorderRadius.circular(TT.rLg),
          boxShadow: TT.shadowCard,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/icon/hero_mountain.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.2),
                filterQuality: FilterQuality.medium,
              ),
              // Bottom-to-surface gradient so the image dissolves into the
              // backdrop rather than abruptly ending.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x0007090C),
                      Color(0x4007090C),
                      Color(0x9907090C),
                    ],
                    stops: [0.4, 0.75, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                right: 14,
                child: Text(
                  'TRAIL PLANNER · LIVE TRACKING · OFFLINE READY',
                  style: TT
                      .mono(
                        size: 10,
                        color: TT.text2,
                        w: FontWeight.w700,
                      )
                      .copyWith(letterSpacing: 0.12 * 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Labeled field wrapper ───────────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: TT
                .mono(size: 10, color: TT.text3, w: FontWeight.w700)
                .copyWith(letterSpacing: 0.14 * 10),
          ),
        ),
        child,
      ],
    );
  }
}

// ─── Primary ember button with press feedback ────────────────────────────────

class _EmberButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const _EmberButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  State<_EmberButton> createState() => _EmberButtonState();
}

class _EmberButtonState extends State<_EmberButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPressed,
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: disabled ? null : (_) => setState(() => _down = false),
      onTapCancel: disabled ? null : () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: TT.dFast,
        curve: TT.easeOut,
        height: 48,
        decoration: BoxDecoration(
          color: disabled ? TT.emberDim : TT.ember,
          borderRadius: BorderRadius.circular(999),
          boxShadow:
              disabled ? null : (_down ? TT.shadowEmber : const <BoxShadow>[]),
          border: Border.all(
            color: disabled ? const Color(0x33FF6A2C) : TT.ember,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: widget.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TT.emberInk,
                ),
              )
            : Text(
                widget.label,
                style: TT
                    .body(
                      size: 14,
                      color: TT.emberInk,
                      w: FontWeight.w800,
                    )
                    .copyWith(letterSpacing: 0.04 * 14),
              ),
      ),
    );
  }
}

// ─── OR divider ──────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: TT.line2, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TT
                .mono(size: 10, color: TT.text3, w: FontWeight.w800)
                .copyWith(letterSpacing: 0.2 * 10),
          ),
        ),
        const Expanded(child: Divider(color: TT.line2, height: 1)),
      ],
    );
  }
}

// ─── Google outline button ───────────────────────────────────────────────────

class _GoogleButton extends StatefulWidget {
  final bool loading;
  final VoidCallback? onPressed;
  const _GoogleButton({required this.loading, required this.onPressed});

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPressed,
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: disabled ? null : (_) => setState(() => _down = false),
      onTapCancel: disabled ? null : () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1.0,
        duration: TT.dFast,
        curve: TT.easeOut,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: TT.surf,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: TT.line2, width: 1),
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TT.text,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _GoogleGlyph(size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: TT.body(
                        size: 14,
                        color: TT.text,
                        w: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Compact "G" mark drawn from quadrant arcs in the official Google colours.
/// Hand-painted rather than icon-fonted so it matches at every density.
class _GoogleGlyph extends StatelessWidget {
  final double size;
  const _GoogleGlyph({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.width / 2;
    final inner = outer * 0.45;
    // 4-coloured arcs forming the iconic G ring.
    const sweeps = <_ArcSpec>[
      _ArcSpec(start: -0.4, sweep: 1.6, color: Color(0xFF4285F4)), // blue
      _ArcSpec(start: 1.2, sweep: 1.4, color: Color(0xFF34A853)), // green
      _ArcSpec(start: 2.6, sweep: 1.2, color: Color(0xFFFBBC05)), // yellow
      _ArcSpec(start: 3.8, sweep: 2.0, color: Color(0xFFEA4335)), // red
    ];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outer - inner
      ..strokeCap = StrokeCap.butt;
    final rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: (outer + inner) / 2,
    );
    for (final s in sweeps) {
      paint.color = s.color;
      canvas.drawArc(rect, s.start, s.sweep, false, paint);
    }
    // Horizontal bar on the right that turns the ring into a "G".
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
          cx, cy - (outer - inner) / 4, outer + 0.5, (outer - inner) / 2),
      bar,
    );
  }

  @override
  bool shouldRepaint(_GoogleGlyphPainter old) => false;
}

class _ArcSpec {
  final double start;
  final double sweep;
  final Color color;
  const _ArcSpec({
    required this.start,
    required this.sweep,
    required this.color,
  });
}

// ─── Subtle link text ────────────────────────────────────────────────────────

class _LinkText extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  const _LinkText({required this.label, this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TT.body(
            size: 12,
            color: enabled ? TT.text2 : TT.text4,
            w: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Forgot password dialog ──────────────────────────────────────────────────

class _ForgotPasswordDialog extends StatelessWidget {
  final String email;
  const _ForgotPasswordDialog({required this.email});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: TTCard(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: TT.emberDim,
                    border:
                        Border.all(color: const Color(0x52FF6A2C), width: 1),
                    borderRadius: BorderRadius.circular(TT.rSm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock_reset_outlined,
                      size: 16, color: TT.ember),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reset password',
                    style: TT.title(16, letterSpacing: -0.01 * 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TT.s3),
            Text(
              "We'll email a password reset link to:",
              style: TT.body(size: 12, color: TT.text2, w: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: TT.surf2,
                border: Border.all(color: TT.line2, width: 1),
                borderRadius: BorderRadius.circular(TT.rSm),
              ),
              child: Text(
                email,
                style: TT.mono(size: 12, color: TT.text, w: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: TT.s4),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TT.surf,
                        border: Border.all(color: TT.line2, width: 1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Cancel',
                        style: TT.body(
                          size: 13,
                          color: TT.text2,
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: TT.s2),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TT.ember,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: TT.shadowEmber,
                      ),
                      child: Text(
                        'Send link',
                        style: TT.body(
                          size: 13,
                          color: TT.emberInk,
                          w: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
