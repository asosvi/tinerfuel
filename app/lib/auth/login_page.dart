import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../ui/messages.dart';

/// algo@dominio.ext, sin espacios.
bool isValidEmail(String email) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[A-Za-z]{2,}$').hasMatch(email.trim());

/// Entrar sin contraseña: código por email, Google o Apple.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.popOnSuccess = false});

  /// Si se abrió para aportar algo: al entrar, vuelve atrás con `true`.
  final bool popOnSuccess;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  StreamSubscription<AuthState>? _sub;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  void initState() {
    super.initState();
    // Google y Apple vuelven a la app por enlace: la sesión llega por aquí.
    _sub = _auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn && mounted) _done();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _done() {
    if (widget.popOnSuccess) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _guard(Future<void> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await op();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _guard(() async {
    final l = AppLocalizations.of(context);
    if (!isValidEmail(_email.text)) {
      showMessage(context, l.invalidEmail, error: true);
      return;
    }
    // El correo trae un código si la plantilla lleva {{ .Token }} (hace falta
    // SMTP propio para editarla) y si no, un enlace que vuelve aquí: en la web
    // a esta misma página y en el móvil a la app (authRedirectUrl).
    await _auth.signInWithOtp(
      email: _email.text.trim(),
      shouldCreateUser: true,
      emailRedirectTo: kIsWeb ? Uri.base.origin : authRedirectUrl,
    );
    setState(() => _codeSent = true);
    if (mounted) showMessage(context, l.codeSent(_email.text.trim()));
  });

  Future<void> _verify() => _guard(() async {
    await _auth.verifyOTP(type: OtpType.email, email: _email.text.trim(), token: _code.text.trim());
    // la navegación la hace el listener de signedIn
  });

  Future<void> _oauth(OAuthProvider provider) => _guard(() async {
    await _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? null : authRedirectUrl,
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (!hasBackend) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l.noBackend)));
    }
    // ya con sesión (p. ej. volvió de Google con la página abierta)
    ref.listen(userProvider, (_, next) {
      if (next.value != null) _done();
    });

    return Scaffold(
      appBar: AppBar(title: Text(l.signIn)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _oauth(OAuthProvider.google),
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: Text(l.continueWithGoogle),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                onPressed: _busy ? null : () => _oauth(OAuthProvider.apple),
                icon: const Icon(Icons.apple),
                label: Text(l.continueWithApple),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l.orDivider)),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),
              TextField(
                controller: _email,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l.email, border: const OutlineInputBorder()),
                onSubmitted: (_) => _sendCode(),
              ),
              const SizedBox(height: 12),
              if (!_codeSent)
                FilledButton(onPressed: _busy ? null : _sendCode, child: Text(l.sendCode))
              else ...[
                TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: InputDecoration(labelText: l.code, border: const OutlineInputBorder()),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _busy ? null : _verify, child: Text(l.verify)),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _codeSent = false),
                  child: Text(l.email),
                ),
              ],
              const SizedBox(height: 24),
              Text.rich(
                TextSpan(
                  text: l.acceptTerms,
                  recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(termsUrl)),
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
