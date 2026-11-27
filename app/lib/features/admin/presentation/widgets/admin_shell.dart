import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/core/widgets/app_brand.dart';
import 'package:tennishub/features/auth/presentation/state/auth_controller.dart';

/// Item do menu lateral do painel.
class AdminDestination {
  const AdminDestination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  /// Se este item corresponde à tela aberta em [location].
  bool matches(String location) {
    return route == AppRoutes.admin
        ? location == route
        : location == route || location.startsWith('$route/');
  }
}

/// Telas do painel no menu lateral. As issues #26 e #27 acrescentam as suas.
const List<AdminDestination> adminDestinations = [
  AdminDestination(
    label: 'Início',
    icon: Icons.home_outlined,
    route: AppRoutes.admin,
  ),
  AdminDestination(
    label: 'Relatórios',
    icon: Icons.bar_chart_outlined,
    route: AppRoutes.adminReports,
  ),
];

/// Estrutura comum das telas do painel: barra superior com o proprietário e
/// o botão "Sair", menu lateral e a tela aberta em [child].
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  /// Caminho da tela aberta, para destacar o item do menu.
  final String location;
  final Widget child;

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    await ref.read(authControllerProvider).signOut();
    router.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final ownerName = ref.watch(sessionStoreProvider)?.owner.name;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppBrand(),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Painel do proprietário',
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: colors.onSecondaryContainer),
              ),
            ),
          ],
        ),
        actions: [
          if (ownerName != null) ...[
            Icon(
              Icons.person_outline,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(ownerName, style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(width: AppSpacing.md),
          ],
          TextButton.icon(
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(location: location),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: AppSpacing.xl,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 248,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 4,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final destination in adminDestinations)
            _SidebarItem(
              destination: destination,
              selected: destination.matches(location),
            ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.home),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Ver área pública'),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.destination, required this.selected});

  final AdminDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? colors.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.go(destination.route),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(destination.icon, size: 20, color: foreground),
                  const SizedBox(width: AppSpacing.md - 4),
                  Text(
                    destination.label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
