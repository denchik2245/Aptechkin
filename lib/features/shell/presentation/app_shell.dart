import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final branch = navigationShell.currentIndex;
    final selected = branch < 2 ? 0 : branch - 1;
    void select(int index) => navigationShell.goBranch(
      index == 0 ? 0 : index + 1,
      initialLocation: index == selected,
    );
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: selected,
        onSelect: select,
        onSearch: () => context.push(AppRoutes.search),
      ),
    );
  }
}

/// The three tabs and the separate search button from the Figma tab bar.
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    required this.selectedIndex,
    this.onSelect,
    this.onSearch,
    this.searchSelected = false,
    super.key,
  });

  /// -1 when no tab is selected (the search is open).
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onSearch;

  /// «tab bar» active=Поиск (824:4908): grey selection, blue icon.
  final bool searchSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = context.palette.tabActive;
    final foreground = theme.colorScheme.onSurface;
    void select(int index) {
      if (onSelect != null) {
        onSelect!(index);
      } else {
        context.go(const ['/', '/reminders', '/settings'][index]);
      }
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GlassSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (final (index, label, icon) in const [
                          (0, 'Аптечка', 'pharmacy'),
                          (1, 'Лечение', 'treatment'),
                          (2, 'Настройки', 'settings'),
                        ])
                          Expanded(
                            child: Semantics(
                              selected: index == selectedIndex,
                              button: true,
                              label: label,
                              excludeSemantics: true,
                              child: Tooltip(
                                message: label,
                                child: Material(
                                  color: index == selectedIndex
                                      ? context.palette.tabSelection
                                      : Colors.transparent,
                                  shape: const StadiumBorder(),
                                  child: InkWell(
                                    customBorder: const StadiumBorder(),
                                    onTap: () => select(index),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 2,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DesignIcon(
                                            icon,
                                            size: 28,
                                            color: index == selectedIndex
                                                ? primary
                                                : foreground,
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            label,
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 10,
                                              height: 1.2,
                                              fontWeight: FontWeight.w700,
                                              color: index == selectedIndex
                                                  ? primary
                                                  : foreground,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassSurface(
                child: SizedBox(
                  width: 62,
                  height: 62,
                  child: Semantics(
                    selected: searchSelected,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 54,
                          height: 54,
                        ),
                        onPressed:
                            onSearch ?? () => context.push(AppRoutes.search),
                        tooltip: 'Поиск',
                        style: searchSelected
                            ? IconButton.styleFrom(
                                backgroundColor: context.palette.tabSelection,
                              )
                            : null,
                        icon: DesignIcon(
                          'search-control',
                          size: 54,
                          color: searchSelected ? primary : foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
