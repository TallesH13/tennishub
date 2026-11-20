import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/core/widgets/app_brand.dart';

/// Layout base de todas as páginas: barra superior com a marca e
/// conteúdo centralizado com largura máxima, pensado para desktop.
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.child, this.actions = const []});

  /// Conteúdo da página.
  final Widget child;

  /// Ações exibidas à direita da barra superior.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < AppBreakpoints.compact
        ? AppSpacing.md
        : AppSpacing.xl;

    return Scaffold(
      appBar: AppBar(
        title: const AppBrand(),
        actions: [
          ...actions,
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: AppSpacing.lg,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
