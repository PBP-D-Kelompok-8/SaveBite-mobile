import 'package:flutter/material.dart';
import 'package:savebite_mobile/jurnal_makanan/jurnal_page.dart';
import 'package:savebite_mobile/main.dart';
import 'package:savebite_mobile/request_board/screens/request_board_page.dart';
import 'package:savebite_mobile/food_rescue_planner/screens/food_rescue_plan_page.dart';

class LeftDrawer extends StatelessWidget {
  const LeftDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'SaveBite',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Food Waste Management',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_rounded),
            title: const Text('Beranda'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyHomePage(title: 'SaveBite'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.forum_rounded),
            title: const Text('Request Board'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RequestBoardPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics_rounded),
            title: const Text('Jurnal Jejak Makanan'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const JurnalPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu_rounded),
            title: const Text('Food Rescue Planner'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const FoodRescuePlanPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
