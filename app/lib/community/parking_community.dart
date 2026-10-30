import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/login_page.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../ui/format.dart';
import '../ui/messages.dart';
import 'community_dialogs.dart';
import 'photo_processing.dart';

String priceKindName(AppLocalizations l, String kind) => switch (kind) {
  'hour' => l.perHour,
  'day' => l.perDay,
  'month' => l.perMonth,
  'flat' => l.flatRate,
  'free' => l.freeOfCharge,
  _ => kind,
};

/// Precios, opiniones y fotos de la comunidad en la ficha de un parking.
class ParkingCommunitySection extends ConsumerWidget {
  const ParkingCommunitySection({super.key, required this.parkingId});

  final String parkingId;

  /// Pide iniciar sesión si hace falta. Devuelve true si hay sesión.
  Future<bool> _ensureSignedIn(BuildContext context, WidgetRef ref) async {
    if (ref.read(userProvider).value != null) return true;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginPage(popOnSuccess: true)),
    );
    return ok ?? false;
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function(Repository) op) async {
    final l = AppLocalizations.of(context);
    try {
      await op(ref.read(repositoryProvider)!);
      ref.invalidate(parkingCommunityProvider(parkingId));
      if (context.mounted) showMessage(context, l.saved);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _addPrice(BuildContext context, WidgetRef ref) async {
    if (!await _ensureSignedIn(context, ref) || !context.mounted) return;
    final result = await showPriceDialog(context);
    if (result == null || !context.mounted) return;
    await _run(
      context,
      ref,
      (r) => r.addPrice(parkingId: parkingId, kind: result.kind, amount: result.amount, note: result.note),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref, ParkingReview? mine) async {
    if (!await _ensureSignedIn(context, ref) || !context.mounted) return;
    final result = await showReviewDialog(context, initial: mine);
    if (result == null || !context.mounted) return;
    await _run(
      context,
      ref,
      (r) => r.saveReview(
        parkingId: parkingId,
        rating: result.rating,
        comment: result.comment,
        existingId: mine?.id,
      ),
    );
  }

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    if (!await _ensureSignedIn(context, ref) || !context.mounted) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 4000, maxHeight: 4000);
    if (picked == null || !context.mounted) return;
    final jpeg = await preparePhoto(await picked.readAsBytes());
    if (!context.mounted) return;
    if (jpeg == null) {
      showError(context, const AppException(AppErrorKind.invalidImage));
      return;
    }
    await _run(context, ref, (r) => r.addPhoto(parkingId: parkingId, jpeg: jpeg));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final me = ref.watch(userProvider).value?.id;
    final repo = ref.watch(repositoryProvider);
    final text = Theme.of(context).textTheme;
    final community = ref.watch(parkingCommunityProvider(parkingId));

    return community.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Column(
        children: [
          Text(errorText(l, e)),
          TextButton(onPressed: () => ref.invalidate(parkingCommunityProvider(parkingId)), child: Text(l.retry)),
        ],
      ),
      data: (c) {
        final mine = c.reviews.where((r) => r.userId == me).firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------- precios
            _SectionTitle(
              title: l.communityPrices,
              action: TextButton.icon(
                onPressed: () => _addPrice(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l.addPrice),
              ),
            ),
            if (c.prices.isEmpty) Text(l.noCommunityPrices, style: text.bodyMedium),
            for (final p in c.prices.take(10))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p.kind == 'free'
                      ? l.freeOfCharge
                      : '${formatMoney(p.amount, locale)} · ${priceKindName(l, p.kind)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    ?p.note,
                    '${p.userId == me ? l.you : (p.authorName ?? '?')} · ${formatAgo(l, p.createdAt)}',
                  ].join('\n'),
                ),
                trailing: _ItemMenu(
                  isMine: p.userId == me,
                  onDelete: () => _run(context, ref, (r) => r.deletePrice(p.id)),
                  targetType: 'price',
                  targetId: p.id,
                  authorId: p.userId,
                  parkingId: parkingId,
                ),
              ),
            const Divider(height: 32),

            // ---------------------------------------------------- opiniones
            _SectionTitle(
              title: c.averageRating == null
                  ? l.reviews
                  : '${l.reviews} · ★ ${c.averageRating!.toStringAsFixed(1)} (${c.reviews.length})',
              action: TextButton.icon(
                onPressed: () => _review(context, ref, mine),
                icon: Icon(mine == null ? Icons.rate_review_outlined : Icons.edit),
                label: Text(mine == null ? l.addReview : l.editReview),
              ),
            ),
            if (c.reviews.isEmpty) Text(l.noReviews, style: text.bodyMedium),
            for (final r in c.reviews.take(20))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${'★' * r.rating}${'☆' * (5 - r.rating)}'),
                subtitle: Text(
                  [
                    ?r.comment,
                    '${r.userId == me ? l.you : (r.authorName ?? '?')} · ${formatAgo(l, r.createdAt)}',
                  ].join('\n'),
                ),
                trailing: _ItemMenu(
                  isMine: r.userId == me,
                  onDelete: () => _run(context, ref, (repo) => repo.deleteReview(r.id)),
                  targetType: 'review',
                  targetId: r.id,
                  authorId: r.userId,
                  parkingId: parkingId,
                ),
              ),
            const Divider(height: 32),

            // ---------------------------------------------------- fotos
            _SectionTitle(
              title: l.photos,
              action: TextButton.icon(
                onPressed: () => _addPhoto(context, ref),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(l.addPhoto),
              ),
            ),
            if (c.photos.isNotEmpty && repo != null)
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: c.photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final photo = c.photos[i];
                    final url = repo.photoUrl(photo.storagePath);
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _openPhoto(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 160,
                              height: 120,
                              fit: BoxFit.cover,
                              cacheWidth: 480,
                              semanticLabel: l.photos,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 160,
                                height: 120,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: _ItemMenu(
                            isMine: photo.userId == me,
                            onDelete: () => _run(context, ref, (r) => r.deletePhoto(photo)),
                            targetType: 'photo',
                            targetId: photo.id,
                            authorId: photo.userId,
                            parkingId: parkingId,
                            onImage: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        action,
      ],
    );
  }
}

/// ⋮ de cada aportación: borrar (si es mía) o denunciar / bloquear al autor.
class _ItemMenu extends ConsumerWidget {
  const _ItemMenu({
    required this.isMine,
    required this.onDelete,
    required this.targetType,
    required this.targetId,
    required this.authorId,
    required this.parkingId,
    this.onImage = false,
  });

  final bool isMine;
  final VoidCallback onDelete;
  final String targetType;
  final String targetId;
  final String authorId;
  final String parkingId;
  final bool onImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn = ref.watch(userProvider).value != null;
    if (!signedIn && !isMine) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: onImage ? Colors.white : null, shadows: onImage
          ? const [Shadow(blurRadius: 4, color: Colors.black)]
          : null),
      onSelected: (action) async {
        final repo = ref.read(repositoryProvider)!;
        switch (action) {
          case 'delete':
            onDelete();
          case 'report':
            final r = await showReportDialog(context);
            if (r == null || !context.mounted) return;
            try {
              await repo.report(targetType: targetType, targetId: targetId, reason: r.reason, details: r.details);
              if (context.mounted) showMessage(context, l.reportSent);
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          case 'block':
            try {
              await repo.block(authorId);
              ref.invalidate(blockedUsersProvider);
              if (context.mounted) showMessage(context, l.blocked);
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
        }
      },
      itemBuilder: (_) => [
        if (isMine) PopupMenuItem(value: 'delete', child: Text(l.delete)),
        if (!isMine) ...[
          PopupMenuItem(value: 'report', child: Text(l.report)),
          PopupMenuItem(value: 'block', child: Text(l.block)),
        ],
      ],
    );
  }
}
