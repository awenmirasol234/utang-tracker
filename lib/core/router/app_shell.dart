import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/features/updater/presentation/widgets/update_auto_checker.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: UpdateAutoChecker(child: navigationShell),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group_rounded),
                label: 'Customers',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Debts',
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Payments',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
