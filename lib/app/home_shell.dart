/// Root shell: 3 thumb-friendly bottom tabs — Chat, Reminders, Life hub.
/// Everything in the app is reachable within 2 taps.
library;

import 'package:flutter/material.dart';
import 'package:memoring/app/theme/app_colors.dart';
import 'package:memoring/features/assistant/presentation/chat_screen.dart';
import 'package:memoring/features/hub/presentation/hub_screen.dart';
import 'package:memoring/features/reminders/presentation/home_screen.dart';

/// Lets any screen switch the shell tab (e.g. the list's FAB → chat).
final ValueNotifier<int> shellTabIndex = ValueNotifier<int>(0);

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: shellTabIndex,
      builder: (context, index, _) {
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: const [ChatScreen(), HomeScreen(), HubScreen()],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.matteBlack,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: BottomNavigationBar(
              currentIndex: index,
              onTap: (i) {
                // Drop the keyboard when leaving the chat tab — every screen
                // opens clean and full-height.
                if (i != 0) FocusManager.instance.primaryFocus?.unfocus();
                shellTabIndex.value = i;
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.shinyWhite,
              unselectedItemColor: AppColors.mutedWhite,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: 'Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.alarm_outlined),
                  activeIcon: Icon(Icons.alarm),
                  label: 'Reminders',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_outlined),
                  activeIcon: Icon(Icons.grid_view_rounded),
                  label: 'Life',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
