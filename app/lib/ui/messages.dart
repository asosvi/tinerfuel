import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repository.dart';
import '../l10n/app_localizations.dart';

/// Aviso abajo de la pantalla; cada uno sustituye al anterior.
void showMessage(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(text, style: TextStyle(color: error ? scheme.onErrorContainer : null)),
        backgroundColor: error ? scheme.errorContainer : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Explica un error en una frase clara.
String errorText(AppLocalizations l, Object error) {
  if (error is AppException) {
    return switch (error.kind) {
      AppErrorKind.rateLimited => l.rateLimited,
      AppErrorKind.alreadyReported => l.alreadyReported,
      AppErrorKind.notSignedIn => l.loginRequired,
      AppErrorKind.invalidImage => l.photoTooBig,
      AppErrorKind.other => l.somethingWrong(error.detail ?? ''),
    };
  }
  if (error is AuthRetryableFetchException || error is TimeoutException) return l.noConnection;
  // Sin dart:io (no existe en la web): se reconoce por el texto.
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('ClientException') || text.contains('Failed host lookup')) {
    return l.noConnection;
  }
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('expired') || m.contains('invalid') || m.contains('token')) return l.invalidCode;
    return l.somethingWrong(error.message);
  }
  if (error is PostgrestException) return l.somethingWrong(error.message);
  return l.somethingWrong(error.toString());
}

void showError(BuildContext context, Object error) =>
    showMessage(context, errorText(AppLocalizations.of(context), error), error: true);
