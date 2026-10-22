import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/router/app_shell.dart';
import 'package:utang_tracker/features/settings/presentation/pages/settings_page.dart';
import 'package:utang_tracker/features/customers/presentation/pages/customer_detail_page.dart';
import 'package:utang_tracker/features/customers/presentation/pages/customer_form_page.dart';
import 'package:utang_tracker/features/customers/presentation/pages/customers_list_page.dart';
import 'package:utang_tracker/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:utang_tracker/features/debts/presentation/pages/debt_detail_page.dart';
import 'package:utang_tracker/features/debts/presentation/pages/debt_form_page.dart';
import 'package:utang_tracker/features/debts/presentation/pages/debts_list_page.dart';
import 'package:utang_tracker/features/payments/presentation/pages/payments_list_page.dart';
import 'package:utang_tracker/features/payments/presentation/pages/record_payment_page.dart';
import 'package:utang_tracker/features/updater/presentation/pages/about_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                builder: (context, state) => const CustomersListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CustomerFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final routeId = state.pathParameters['id']!;
                      return CustomerDetailPage(customerId: routeId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final routeId = state.pathParameters['id']!;
                          return CustomerFormPage(customerId: routeId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/debts',
                builder: (context, state) => const DebtsListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final customerId =
                          state.uri.queryParameters['customerId'];
                      return DebtFormPage(initialCustomerId: customerId);
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final routeId = state.pathParameters['id']!;
                      return DebtDetailPage(debtId: routeId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final routeId = state.pathParameters['id']!;
                          return DebtFormPage(debtId: routeId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/payments',
                builder: (context, state) => const PaymentsListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final debtId = state.uri.queryParameters['debtId'];
                      return RecordPaymentPage(initialDebtId: debtId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutPage(),
      ),
    ],
  );
}
