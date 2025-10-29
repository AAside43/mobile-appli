import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_appli_1/store/room_store.dart';
import 'package:mobile_appli_1/store/dashboard_screen.dart';
import 'package:mobile_appli_1/store/rooms_screen.dart';
import 'package:mobile_appli_1/store/history_screen.dart';
import 'package:mobile_appli_1/store/add_room_screen.dart';

class RoomManagerApp extends StatelessWidget {
  const RoomManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoomStore()..loadSample(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Room Manager',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    RoomsScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddRoomScreen()),
            ),
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (v) => setState(() => _index = v),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.meeting_room), label: 'Rooms'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
