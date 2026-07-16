import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/clients/presentation/clients_screen.dart';
import '../../features/clients/presentation/client_form_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/orders/presentation/order_form_screen.dart';
import '../../features/equipment/presentation/equipment_screen.dart';
import '../../features/planning/presentation/planning_screen.dart';
import '../../features/production/presentation/production_screen.dart';
import '../../features/absences/presentation/absences_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/messaging/presentation/messaging_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../../features/auth/data/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
      GoRoute(path: '/change-password', builder: (ctx, _) => const ChangePasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (ctx, _) => const DashboardScreen()),
          GoRoute(
            path: '/clients',
            builder: (ctx, _) => const ClientsScreen(),
            routes: [
              GoRoute(path: 'new', builder: (ctx, _) => const ClientFormScreen()),
              GoRoute(path: 'edit/:id', builder: (ctx, state) => ClientFormScreen(clientId: int.parse(state.pathParameters['id']!))),
            ],
          ),
          GoRoute(
            path: '/orders',
            builder: (ctx, _) => const OrdersScreen(),
            routes: [
              GoRoute(path: 'new', builder: (ctx, _) => const OrderFormScreen()),
              GoRoute(path: 'edit/:id', builder: (ctx, state) => OrderFormScreen(orderId: int.parse(state.pathParameters['id']!))),
            ],
          ),
          GoRoute(path: '/equipment', builder: (ctx, _) => const EquipmentScreen()),
          GoRoute(path: '/planning', builder: (ctx, _) => const PlanningScreen()),
          GoRoute(path: '/production', builder: (ctx, _) => const ProductionScreen()),
          GoRoute(path: '/absences', builder: (ctx, _) => const AbsencesScreen()),
          GoRoute(path: '/notifications', builder: (ctx, _) => const NotificationsScreen()),
          GoRoute(path: '/messaging', builder: (ctx, _) => const MessagingScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}', style: const TextStyle(color: Colors.white)),
      ),
    ),
  );
});
