/*// Required Flutter material components for UI elements
import 'package:flutter/material.dart';
// Room service for fetching room data
import 'package:test_the_app/services/room_service.dart';
import 'package:test_the_app/services/auth_service.dart';
// Room model
import 'package:test_the_app/models/room.dart';

// Login page route name for navigation
const String loginRoute = '/login';

// Room list screen showing available rooms
class RoomListPage extends StatefulWidget {
  final String authToken; // JWT token from login

  const RoomListPage({super.key, required this.authToken});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  // Service instances
  final RoomService _roomService = RoomService();
  final AuthService _authService = AuthService();

  // State variables
  bool _isLoading = true;
  List<Room> _rooms = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms(); // Load rooms when widget initializes
  }

  // Fetch rooms from server
  Future<void> _loadRooms() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get rooms from server using the room service
      _rooms = await _roomService.getRooms(widget.authToken);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load rooms: $e';
      });
      // If unauthorized, redirect to login
      if (e.toString().contains('unauthorized') ||
          e.toString().contains('401')) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(loginRoute);
        }
      }
    }
  }

  // Handle room selection and booking
  void _selectRoom(Room room) async {
    if (!room.isAvailable) {
      _showMessage('This room is not available', isError: true);
      return;
    }

    try {
      await _roomService.bookRoom(widget.authToken, room.id);
      _showMessage('Successfully booked ${room.name}');
      // Refresh the room list
      _loadRooms();
    } catch (e) {
      _showMessage('Failed to book room: Please try again', isError: true);
    }
  }

  // Show feedback messages to user
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  // Handle logout: ask for confirmation then perform logout
  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show a simple blocking progress indicator while logging out
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _auth_service_logout_safe();
      if (mounted) {
        Navigator.of(context).pop(); // remove progress
        Navigator.of(context).pushReplacementNamed(loginRoute);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // remove progress
        // Redirect to login even if server logout failed so user is returned to auth
        Navigator.of(context).pushReplacementNamed(loginRoute);
        // Show non-blocking error message after redirect
        _showMessage('Logout failed (server): $e', isError: true);
      }
    }
  }

  // Helper to call authService.logout and catch non-fatal errors
  Future<void> _auth_service_logout_safe() async {
    try {
      await _authService.logout(widget.authToken);
    } catch (e) {
      // Log or ignore - we'll show user-friendly message from caller
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rooms'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadRooms,
            tooltip: 'Refresh room list',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadRooms,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRooms,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _rooms.length,
                itemBuilder: (context, index) {
                  final room = _rooms[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.meeting_room,
                        color: room.isAvailable ? Colors.green : Colors.red,
                      ),
                      title: Text(room.name),
                      subtitle: Text(
                        '${room.description}\nCapacity: ${room.capacity} people',
                      ),
                      trailing: room.isAvailable
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.cancel, color: Colors.red),
                      onTap: () => _selectRoom(room),
                    ),
                  );
                },
              ),
            ),
    );
  }
}*/

