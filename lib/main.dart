import 'dart:ui' show ImageFilter;

import 'package:family_mafia_app/navigation/app_tabs.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final scale = mediaQuery.textScaler.clamp(
          minScaleFactor: 1.15,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: scale),
          child: child!,
        );
      },
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
  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(initialLoadProvider).isLoading;
    // Kick off background loading of remaining seasons
    ref.watch(backgroundLoadProvider);
    final tabs = appTabsFor(isWeb: kIsWeb);
    final index = visibleTabIndex(ref.watch(selectedTabProvider), tabs.length);

    return Scaffold(
      extendBody: !isLoading,
      body: IndexedStack(index: index, children: [for (final t in tabs) t.screen]),
      bottomNavigationBar: isLoading ? null : ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: NavigationBar(
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            selectedIndex: index,
            onDestinationSelected: (i) => ref.read(selectedTabProvider.notifier).state = i,
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                  label: t.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
