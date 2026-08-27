import 'package:flutter/material.dart';
import 'core/supabase_client.dart';
import 'core/auth_service.dart';
import 'modules/module1_explorer/screens/explorer_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await AuthService.ensureSignedIn();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnJejak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff00695c)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// Separate widget so its `context` is a descendant of MaterialApp —
/// required for ScaffoldMessenger.of(context) / Scaffold.of(context) to work.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const _titles = ['Explore', 'Reliability', 'Reports', 'Alerts'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OnJejak · ${_titles[_selectedIndex]}')),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          ExplorerHomePage(),
          _ComingSoonPage(moduleName: 'Reliability'),
          _ComingSoonPage(moduleName: 'Reports'),
          _ComingSoonPage(moduleName: 'Alerts'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Reliability'),
          NavigationDestination(icon: Icon(Icons.report_outlined), selectedIcon: Icon(Icons.report), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
        ],
      ),
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.moduleName});

  final String moduleName;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$moduleName module is being prepared.'));
  }
}
