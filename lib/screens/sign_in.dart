import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/widgets.dart';

/// Email + password auth against Supabase. Only reachable when a project is
/// configured; demo mode skips it.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.signUp = false});

  final bool signUp;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late bool _signUp = widget.signUp;
  final _business = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _business.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.length < 6) {
      toast(context, 'Enter your email and a password of at least 6 characters');
      return;
    }
    setState(() => _busy = true);
    final auth = Supabase.instance.client.auth;
    try {
      if (_signUp) {
        final res = await auth.signUp(
          email: email,
          password: password,
          data: {'business_name': _business.text.trim()},
        );
        if (res.session == null) {
          if (!mounted) return;
          toast(context, 'Check your email to confirm your account, then sign in');
          setState(() => _signUp = false);
          return;
        }
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
      Haptics.success();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, 'Something went wrong — try again');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;

    return ScreenScaffold(
      header: TopBar(title: _signUp ? 'Create your account' : 'Sign in'),
      bottom: [
        Expanded(
          child: DaylitButton(
            _busy ? 'One moment…' : (_signUp ? 'Create account' : 'Sign in'),
            onTap: _busy ? null : _submit,
          ),
        ),
      ],
      children: stagger([
        if (_signUp) ...[
          _Input(label: 'Business name', controller: _business, hint: 'Northwind Studio', autofocus: true),
          const SizedBox(height: 10),
        ],
        _Input(label: 'Email', controller: _email, hint: 'you@company.com', keyboard: TextInputType.emailAddress, autofocus: !_signUp),
        const SizedBox(height: 10),
        _Input(
          label: 'Password',
          controller: _password,
          hint: 'At least 6 characters',
          obscure: !_showPassword,
          onSubmit: _submit,
          trailing: Pressable(
            onTap: () => setState(() => _showPassword = !_showPassword),
            scale: 0.85,
            semanticLabel: _showPassword ? 'Hide password' : 'Show password',
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Icon(
                _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: dl.muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Pressable(
            onTap: () => setState(() => _signUp = !_signUp),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _signUp ? 'Already have an account? Sign in' : 'New to Invonce? Create an account',
                style: Fonts.sans(size: 14, weight: FontWeight.w600, color: dl.rust),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboard,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmit,
    this.trailing,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool obscure;
  final bool autofocus;
  final VoidCallback? onSubmit;

  /// e.g. the show/hide-password eye.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dl = context.dl;
    final field = TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      autofocus: autofocus,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: Fonts.body(dl.ink),
      cursorColor: Palette.wine,
      onSubmitted: (_) => onSubmit?.call(),
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: Fonts.sans(size: 15, color: dl.muted),
      ),
    );
    return FieldTile(
      label: label,
      child: trailing == null ? field : Row(children: [Expanded(child: field), trailing!]),
    );
  }
}
