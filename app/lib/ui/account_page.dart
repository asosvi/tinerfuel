import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/login_page.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'messages.dart';

/// Cuenta, idioma, personas bloqueadas, enlaces legales y borrar la cuenta.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(userProvider).value;
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.account)),
      body: ListView(
        children: [
          if (user == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l.signIn),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginPage())),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user.email ?? user.id),
            ),
            const _DisplayNameTile(),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l.blockedUsers),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _BlockedUsersPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l.signOut),
              onTap: () => ref.read(repositoryProvider)?.db.auth.signOut(),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            trailing: DropdownButton<String>(
              value: locale?.languageCode ?? '',
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: '', child: Text(l.systemLanguage)),
                const DropdownMenuItem(value: 'es', child: Text('Español')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) =>
                  ref.read(localeProvider.notifier).set(v == null || v.isEmpty ? null : Locale(v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.privacy),
            onTap: () => launchUrl(Uri.parse(privacyUrl)),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.terms),
            onTap: () => launchUrl(Uri.parse(termsUrl)),
          ),
          AboutListTile(
            icon: const Icon(Icons.info_outline),
            applicationName: appName,
            aboutBoxChildren: [Text(l.dataSources)],
            child: Text(l.about),
          ),
          if (user != null) ...[
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
              title: Text(l.deleteAccount, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => _deleteAccount(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l.deleteAccount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.deleteAccountConfirm),
              TextField(controller: controller, onChanged: (_) => setState(() {})),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: controller.text.trim().toUpperCase() == l.deleteWord
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text(l.delete),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(repositoryProvider)!.deleteAccount();
      if (context.mounted) showMessage(context, l.accountDeleted);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _DisplayNameTile extends ConsumerStatefulWidget {
  const _DisplayNameTile();

  @override
  ConsumerState<_DisplayNameTile> createState() => _DisplayNameTileState();
}

class _DisplayNameTileState extends ConsumerState<_DisplayNameTile> {
  late Future<String?> _name = ref.read(repositoryProvider)!.myDisplayName();

  Future<void> _edit(String? current) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.displayName),
        content: TextField(controller: controller, maxLength: 50, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: Text(l.save)),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || !mounted) return;
    try {
      await ref.read(repositoryProvider)!.setDisplayName(value);
      setState(() => _name = Future.value(value.trim()));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<String?>(
      future: _name,
      builder: (context, snap) => ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(l.displayName),
        subtitle: Text(snap.data ?? '…'),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _edit(snap.data),
      ),
    );
  }
}

class _BlockedUsersPage extends ConsumerWidget {
  const _BlockedUsersPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final blocked = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.blockedUsers)),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorText(l, e))),
        data: (users) => users.isEmpty
            ? Center(child: Text(l.noBlockedUsers))
            : ListView(
                children: [
                  for (final e in users.entries)
                    ListTile(
                      title: Text(e.value),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(repositoryProvider)!.unblock(e.key);
                            ref.invalidate(blockedUsersProvider);
                          } catch (err) {
                            if (context.mounted) showError(context, err);
                          }
                        },
                        child: Text(l.unblock),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
