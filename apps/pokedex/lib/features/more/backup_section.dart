import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import '../../app/backup_files.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/text_input_dialog.dart';

// Standalone functions: the closures passed to the isolate must not capture
// anything from the UI (State, BuildContext).
Future<List<int>> _encodeInBackground(BackupData data, String? password) =>
    Isolate.run(() => BackupCodec.encode(data, password: password));

Future<BackupData> _decodeInBackground(Uint8List bytes, String? password) =>
    Isolate.run(() => BackupCodec.decode(bytes, password: password));

/// Export and import of all personal data.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  Future<BackupData> _currentData() async {
    final storage = ref.read(appStorageProvider);
    return BackupData(
      collection: (await storage.collection.loadAll()).values.toList(),
      teams: await storage.teams.loadAll(),
      presets: await storage.presets.loadAll(),
      preferences: ref.read(settingsProvider).toJson(),
      createdAt: DateTime.now(),
    );
  }

  void _show(String message) => ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e, stack) {
      // Never swallow errors: report and show them.
      debugPrint('Backup failed: $e\n$stack');
      if (mounted) _show(l10n.backupError('other'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _ExportPasswordDialog(),
    );
    if (password == null) return; // abgebrochen
    await _run(() async {
      final data = await _currentData();
      // Key derivation and encryption do not block the UI.
      final bytes = await _encodeInBackground(
        data,
        password.isEmpty ? null : password,
      );
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final saved = await ref
          .read(backupFilesProvider)
          .save(Uint8List.fromList(bytes), 'mydex-backup-$date.json');
      if (saved && mounted) _show(l10n.exportDone);
    });
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final bytes = await ref.read(backupFilesProvider).open();
    if (bytes == null || !mounted) return;
    BackupData incoming;
    try {
      String? password;
      if (BackupCodec.isEncrypted(bytes)) {
        password = await _askPassword();
        if (password == null) return;
      }
      setState(() => _busy = true);
      incoming = await _decodeInBackground(bytes, password);
    } on BackupException catch (e) {
      if (mounted) _show(l10n.backupError(e.error.name));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final current = await _currentData();
    if (!mounted) return;
    final plan = await showDialog<ImportPlan>(
      context: context,
      builder: (_) =>
          _ImportPreviewDialog(current: current, incoming: incoming),
    );
    if (plan == null) return;
    await _run(() async {
      final storage = ref.read(appStorageProvider);
      await storage.collection.replaceAll(plan.collection);
      await storage.teams.replaceAll(plan.teams);
      await storage.presets.replaceAll(plan.presets);
      if (plan.preferences case final prefs?) {
        ref
            .read(settingsProvider.notifier)
            .replaceAll(AppSettings.fromJson(prefs));
      }
      ref
        ..invalidate(collectionProvider)
        ..invalidate(teamsProvider)
        ..invalidate(presetsProvider);
      if (mounted) _show(l10n.importDone);
    });
  }

  Future<String?> _askPassword() {
    final l10n = AppLocalizations.of(context);
    return showTextInputDialog(
      context,
      title: l10n.importPasswordTitle,
      label: l10n.password,
      confirm: l10n.importBackup,
      cancel: l10n.cancel,
      obscure: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: Text(
            l10n.backupExplanation,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: Space.m),
                Text(l10n.working),
              ],
            ),
          ),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: Text(l10n.exportBackup),
          enabled: !_busy,
          onTap: _export,
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(l10n.importBackup),
          enabled: !_busy,
          onTap: _import,
        ),
      ],
    );
  }
}

/// Returns the password ('' = none) or `null` when cancelled.
class _ExportPasswordDialog extends StatefulWidget {
  const _ExportPasswordDialog();

  @override
  State<_ExportPasswordDialog> createState() => _ExportPasswordDialogState();
}

class _ExportPasswordDialogState extends State<_ExportPasswordDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.exportBackup),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _first,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.backupPassword),
          ),
          TextField(
            controller: _second,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.backupPasswordRepeat,
              errorText: _error,
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            l10n.backupPasswordHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_first.text != _second.text) {
              setState(() => _error = l10n.passwordsDiffer);
              return;
            }
            Navigator.pop(context, _first.text);
          },
          child: Text(l10n.exportBackup),
        ),
      ],
    );
  }
}

class _ImportPreviewDialog extends StatefulWidget {
  const _ImportPreviewDialog({required this.current, required this.incoming});

  final BackupData current;
  final BackupData incoming;

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  ImportMode _mode = ImportMode.merge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = planImport(
      current: widget.current,
      incoming: widget.incoming,
      mode: _mode,
    );
    final date = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(widget.incoming.createdAt.toLocal());
    String counts(String label, ImportCounts c) =>
        l10n.importCounts(label, c.added, c.updated, c.kept, c.removed);
    return AlertDialog(
      title: Text(l10n.importPreviewTitle(date)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<ImportMode>(
              segments: [
                ButtonSegment(
                  value: ImportMode.merge,
                  label: Text(l10n.importModeMerge),
                ),
                ButtonSegment(
                  value: ImportMode.replace,
                  label: Text(l10n.importModeReplace),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.single),
            ),
            const SizedBox(height: Space.s),
            Text(
              _mode == ImportMode.merge
                  ? l10n.importModeMergeHint
                  : l10n.importModeReplaceHint,
            ),
            const SizedBox(height: Space.m),
            Text(counts(l10n.collectionLabel, plan.collectionCounts)),
            Text(counts(l10n.teamsTitle, plan.teamCounts)),
            Text(counts(l10n.presets, plan.presetCounts)),
            if (widget.incoming.skippedEntries > 0) ...[
              const SizedBox(height: Space.s),
              Text(l10n.importSkipped(widget.incoming.skippedEntries)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, plan),
          child: Text(l10n.importBackup),
        ),
      ],
    );
  }
}
