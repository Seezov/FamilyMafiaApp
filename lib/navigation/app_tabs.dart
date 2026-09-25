import 'package:family_mafia_app/screens/chat/chat_screen.dart';
import 'package:family_mafia_app/screens/dashboard/dashboard_screen.dart';
import 'package:family_mafia_app/screens/debug/debug_screen.dart';
import 'package:family_mafia_app/screens/home/home_screen.dart';
import 'package:family_mafia_app/screens/players/players_screen.dart';
import 'package:family_mafia_app/screens/records/records_screen.dart';
import 'package:flutter/material.dart';

/// One bottom-nav destination and the screen it shows.
class AppTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  /// Hidden on the web: Chat costs money per request and Debug is an
  /// internal tool that needs the file system.
  final bool mobileOnly;

  const AppTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
    this.mobileOnly = false,
  });
}

const _allTabs = <AppTab>[
  AppTab(label: 'Season', icon: Icons.home_outlined, selectedIcon: Icons.home, screen: HomeScreen()),
  AppTab(label: 'Players', icon: Icons.people_outline, selectedIcon: Icons.people, screen: PlayersScreen()),
  AppTab(label: 'Dashboard', icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, screen: DashboardScreen()),
  AppTab(label: 'Records', icon: Icons.emoji_events_outlined, selectedIcon: Icons.emoji_events, screen: RecordsScreen()),
  AppTab(label: 'Chat', icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, screen: ChatScreen(), mobileOnly: true),
  AppTab(label: 'Debug', icon: Icons.bug_report_outlined, selectedIcon: Icons.bug_report, screen: DebugScreen(), mobileOnly: true),
];

/// The tabs shown on this platform. Mobile-only tabs are last, so indices of
/// the shared tabs are the same everywhere.
List<AppTab> appTabsFor({required bool isWeb}) =>
    isWeb ? _allTabs.where((t) => !t.mobileOnly).toList() : _allTabs;

/// [selected] clamped to the tabs this platform actually has, so a stale
/// index (e.g. Chat on the web) shows the last tab instead of crashing.
int visibleTabIndex(int selected, int tabCount) =>
    selected.clamp(0, tabCount - 1);
