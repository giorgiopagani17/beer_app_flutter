import 'package:flutter/material.dart';
import '../pages/login_page.dart';
import '../pages/main_navigation_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String mainNavigation = '/main';
  
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case mainNavigation:
        return MaterialPageRoute(builder: (_) => const MainNavigationPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}