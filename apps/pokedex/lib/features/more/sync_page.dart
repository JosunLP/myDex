import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/sync_controller.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Optional sync with your own server (ADR 0012).
class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _passphrase = TextEditingController();
  bool _busy = false;
  bool _showToken = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action, String? success) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    final message = error == null ? success : l10n.syncError(error);
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _wipe() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.syncWipe),
        content: Text(l10n.syncWipeConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => ref.read(syncProvider.notifier).disconnect(wipeServer: true),
      l10n.syncWiped,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(syncProvider);
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(syncProvider.notifier);
    final busy = _busy || status.syncing;

    final note = Card(
      child: ListTile(
        leading: const Icon(Icons.shield_outlined),
        title: Text(l10n.syncPrivacyNote),
      ),
    );

    final List<Widget> body;
    if (!status.connected) {
      body = [
        Text(l10n.syncIntro),
        const SizedBox(height: Space.l),
        note,
        const SizedBox(height: Space.l),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l10n.syncServerUrl,
            hintText: 'https://sync.example.org',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: Space.m),
        TextField(
          controller: _token,
          obscureText: !_showToken,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.syncToken,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: l10n.syncShowToken,
              icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showToken = !_showToken),
            ),
          ),
        ),
        const SizedBox(height: Space.m),
        TextField(
          controller: _passphrase,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.syncPassphrase,
            helperText: l10n.syncPassphraseHint,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ),
        if (status.error != null) ...[
          const SizedBox(height: Space.m),
          Text(
            l10n.syncError(status.error!),
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Space.l),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: busy
                ? null
                : () => _run(
                    () => controller.connect(
                      _url.text,
                      _token.text,
                      _passphrase.text,
                    ),
                    l10n.syncConnected,
                  ),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link),
            label: Text(busy ? l10n.syncUnlocking : l10n.syncConnect),
          ),
        ),
      ];
    } else {
      final last = status.lastSync;
      final report = status.lastReport;
      body = [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(status.config!.serverUrl),
          subtitle: Text(
            [
              last == null
                  ? l10n.syncNever
                  : l10n.syncLastSync(
                      DateFormat.yMd(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).add_Hm().format(last),
                    ),
              if (status.pending > 0) l10n.syncPending(status.pending),
            ].join(' · '),
          ),
        ),
        if (report != null)
          Text(
            [
              l10n.syncReport(report.sent, report.received),
              if (report.copies > 0) l10n.syncCopies(report.copies),
            ].join(' · '),
            style: textTheme.bodySmall,
          ),
        if (status.error != null) ...[
          const SizedBox(height: Space.s),
          Text(
            l10n.syncError(status.error!),
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Space.l),
        Wrap(
          spacing: Space.m,
          runSpacing: Space.m,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : () => _run(controller.syncNow, null),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(busy ? l10n.syncRunning : l10n.syncNow),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => _run(controller.disconnect, l10n.syncDisconnected),
              icon: const Icon(Icons.link_off),
              label: Text(l10n.syncDisconnect),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        note,
        const SizedBox(height: Space.l),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : _wipe,
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(l10n.syncWipe),
          ),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Space.l),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
