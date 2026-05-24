import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:muhafiz/core/constants.dart';
import 'package:muhafiz/router.dart';

import 'package:muhafiz/screens/alert_history_screen.dart';
import 'package:muhafiz/screens/home_screen.dart';
import 'package:muhafiz/screens/contacts_screen.dart';
import 'package:muhafiz/screens/settings_screen.dart';
import 'package:muhafiz/screens/safety_center_screen.dart';
import 'package:muhafiz/screens/profile_screen.dart';


class AppShell extends ConsumerStatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _currentIndex;
  StreamSubscription<Uri?>? _widgetClickedSubscription;

  static const _activeColor = AppColors.primary;
  static const _inactiveColor = Color(0xFF9E9E9E);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    // Listen to deep links from Home Widget when app is already running
    _widgetClickedSubscription = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    
    // Check if app was initially launched via a Home Widget click
    _checkInitialWidgetUri();
    _screens = const [
      HomeScreen(),
      SafetyCenterScreen(),
      AlertHistoryScreen(),
      ContactsScreen(),
      ProfileScreen(),
      SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(
              top: BorderSide(color: AppColors.black.withValues(alpha: 0.08)),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.white,
            elevation: 0,
            selectedItemColor: _activeColor,
            unselectedItemColor: _inactiveColor,
            selectedLabelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
            ),
            selectedFontSize: 10,
            unselectedFontSize: 10,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                activeIcon: Icon(Icons.home_rounded, size: 26),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.health_and_safety_rounded),
                activeIcon: Icon(Icons.health_and_safety_rounded, size: 26),
                label: 'Safety',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_active_rounded),
                activeIcon: Icon(Icons.notifications_active_rounded, size: 26),
                label: 'Alerts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.contacts_rounded),
                activeIcon: Icon(Icons.contacts_rounded, size: 26),
                label: 'Contacts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                activeIcon: Icon(Icons.person_rounded, size: 26),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded),
                activeIcon: Icon(Icons.settings_rounded, size: 26),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _widgetClickedSubscription?.cancel();
    super.dispose();
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    if (uri.scheme == 'muhafiz') {
      if (uri.host == 'emergency') {
        Navigator.pushNamed(context, AppRoutes.emergency, arguments: {'autoStart': true});
      } else if (uri.host == 'vulnerable') {
        Navigator.pushNamed(context, AppRoutes.vulnerable);
      }
    }
  }

  Future<void> _checkInitialWidgetUri() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (uri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleWidgetUri(uri);
        });
      }
    } catch (_) {}
  }
}
