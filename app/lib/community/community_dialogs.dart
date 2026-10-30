import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';
import 'parking_community.dart';

/// Límites (iguales que en supabase/migrations/002_community.sql).
abstract final class CommunityLimits {
  static const maxAmount = 1000.0;
  static const note = 300;
  static const comment = 1000;
  static const reportDetails = 1000;
}

/// '2,50' o '2.50' -> 2.5; null si no es un importe válido.
double? parseAmount(String text) {
  final v = double.tryParse(text.trim().replaceAll(',', '.'));
  if (v == null || v < 0 || v > CommunityLimits.maxAmount) return null;
  return (v * 100).roundToDouble() / 100;
}

typedef PriceInput = ({String kind, double amount, String? note});

Future<PriceInput?> showPriceDialog(BuildContext context) {
  return showDialog<PriceInput>(context: context, builder: (_) => const _PriceDialog());
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog();

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  String _kind = 'hour';
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final amount = _kind == 'free' ? 0.0 : parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = AppLocalizations.of(context).invalidAmount);
      return;
    }
    Navigator.of(context).pop((kind: _kind, amount: amount, note: _note.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.addPrice),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: l.priceKind),
              items: [
                for (final k in parkingPriceKinds)
                  DropdownMenuItem(value: k, child: Text(priceKindName(l, k))),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'hour'),
            ),
            if (_kind != 'free')
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(7)],
                decoration: InputDecoration(labelText: l.amountEuros, errorText: _error),
                onSubmitted: (_) => _save(),
              ),
            TextField(
              controller: _note,
              maxLength: CommunityLimits.note,
              decoration: InputDecoration(labelText: l.noteOptional),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

typedef ReviewInput = ({int rating, String? comment});

Future<ReviewInput?> showReviewDialog(BuildContext context, {ParkingReview? initial}) {
  return showDialog<ReviewInput>(context: context, builder: (_) => _ReviewDialog(initial: initial));
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({this.initial});

  final ParkingReview? initial;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late int _rating = widget.initial?.rating ?? 0;
  late final _comment = TextEditingController(text: widget.initial?.comment);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? l.addReview : l.editReview),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.rating),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i',
                    icon: Icon(i <= _rating ? Icons.star : Icons.star_border, color: Colors.amber.shade700),
                    onPressed: () => setState(() => _rating = i),
                  ),
              ],
            ),
            TextField(
              controller: _comment,
              maxLines: 4,
              maxLength: CommunityLimits.comment,
              decoration: InputDecoration(labelText: l.commentOptional),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          onPressed: _rating == 0
              ? null
              : () => Navigator.of(context).pop((rating: _rating, comment: _comment.text)),
          child: Text(l.save),
        ),
      ],
    );
  }
}

typedef ReportInput = ({String reason, String? details});

Future<ReportInput?> showReportDialog(BuildContext context) {
  return showDialog<ReportInput>(context: context, builder: (_) => const _ReportDialog());
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reasons = {
      'spam': l.reasonSpam,
      'offensive': l.reasonOffensive,
      'false': l.reasonFalse,
      'personal_data': l.reasonPersonalData,
      'other': l.reasonOther,
    };
    return AlertDialog(
      title: Text(l.report),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final e in reasons.entries)
                    RadioListTile<String>(value: e.key, title: Text(e.value), contentPadding: EdgeInsets.zero),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: CommunityLimits.reportDetails,
              decoration: InputDecoration(labelText: l.detailsOptional),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop((reason: _reason!, details: _details.text)),
          child: Text(l.report),
        ),
      ],
    );
  }
}
