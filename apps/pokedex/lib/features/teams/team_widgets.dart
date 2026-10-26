import 'package:flutter/material.dart';
import 'package:mydex_application/mydex_application.dart';

import '../../l10n/generated/app_localizations.dart';

/// Status mit Symbol und Text (nie nur Farbe).
class CheckStatusIcon extends StatelessWidget {
  const CheckStatusIcon(this.status, {super.key, this.showLabel = false});

  final CheckStatus status;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      CheckStatus.valid => (Icons.check_circle_outline, scheme.primary),
      CheckStatus.partial => (Icons.info_outline, scheme.secondary),
      CheckStatus.insufficientData => (
        Icons.construction_outlined,
        scheme.tertiary,
      ),
      CheckStatus.invalid => (Icons.error_outline, scheme.error),
    };
    final label = l10n.checkStatus(status.name);
    final iconWidget = Icon(
      icon,
      color: color,
      semanticLabel: showLabel ? null : label,
    );
    if (!showLabel) return Tooltip(message: label, child: iconWidget);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Lokalisierter Text einer Prüfmeldung.
String describeIssue(
  CheckIssue issue,
  AppLocalizations l10n,
  String Function(String subject) subjectName,
) {
  final text = l10n.issue(issue.kind.name);
  return issue.subject == null
      ? text
      : l10n.issueWithSubject(text, subjectName(issue.subject!));
}
