import 'dart:ui' show ImageFilter;

import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/chat/chat_screen.dart';
import 'package:family_mafia_app/screens/dashboard/dashboard_screen.dart';
import 'package:family_mafia_app/screens/home/home_screen.dart';
import 'package:family_mafia_app/screens/players/players_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Mafia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const _RootNav(),
    );
  }
}

class _RootNav extends ConsumerStatefulWidget {
  const _RootNav();

  @override
  ConsumerState<_RootNav> createState() => _RootNavState();
}

class _RootNavState extends ConsumerState<_RootNav> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    PlayersScreen(),
    DashboardScreen(),
    ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(initialLoadProvider).isLoading;
    // Kick off background loading of remaining seasons
    ref.watch(backgroundLoadProvider);

    return Scaffold(
      extendBody: !isLoading,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: isLoading ? null : ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: NavigationBar(
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Season',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Players',
              ),
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
