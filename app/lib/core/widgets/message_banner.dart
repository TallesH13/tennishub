import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/theme/app_colors.dart';
import 'package:tennishub/core/theme/app_spacing.dart';

/// Tipo de aviso exibido dentro da página.
enum MessageKind { error, warning, info }

/// Aviso dentro da página: erro, atenção ou informação.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.message,
    this.kind = MessageKind.error,
  });

  final String message;
  final MessageKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (kind) {
      MessageKind.error => (
        colors.errorContainer,
        colors.onErrorContainer,
        Icons.error_outline,
      ),
      MessageKind.warning => (
        AppColors.warningContainer,
        AppColors.onWarningContainer,
        Icons.warning_amber,
      ),
      MessageKind.info => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
        Icons.info_outline,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: AppSpacing.md - 4),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
