import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Import หน้า Login
import 'login_page.dart';

// 2. Import หน้าหลักของแต่ละ Role (ตรวจสอบ path ให้ถูกต้องตามเครื่องคุณ)
import 'student/student_home_page.dart';      
import 'lecturer/lecturer_dashboard_page.dart';
import 'staff/staff_dashboard_page.dart';
import 'services/sse_service.dart';

class AuthCheckWrapper extends StatefulWidget {
  const AuthCheckWrapper({Key? key}) : super(key: key);

  @override
  State<AuthCheckWrapper> createState() => _AuthCheckWrapperState();
}

class _AuthCheckWrapperState extends State<AuthCheckWrapper> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // รอให้ Build context พร้อมก่อนเล็กน้อย (ป้องกัน error จอดำในบางกรณี)
    await Future.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();

    // ดึงข้อมูลจากเครื่อง
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? role = prefs.getString('role');
    final String? token = prefs.getString('token');

    if (!mounted) return;

    // ตรวจสอบเงื่อนไข: ต้อง Login แล้ว + มี Role + มี Token
    if (isLoggedIn && role != null && token != null) {
      
      print("✅ Auto-Login as: $role"); // Debug log
      
      // Connect to SSE for real-time updates
      try {
        await sseService.connect();
        print("🔌 Connected to real-time updates");
      } catch (e) {
        print("⚠️ SSE connection failed: $e");
      }

      // --- 3. แยกทางตาม Role ---
      if (role == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentHomePage()),
        );
      } else if (role == 'lecturer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LecturerDashboardPage()),
        );
      } else if (role == 'staff') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
        );
      } else {
        // กรณี Role ไม่ถูกต้อง (กันเหนียว) ให้กลับไป Login
        print("❌ Unknown role: $role");
        _navigateToLogin();
      }

    } else {
      // ถ้ายังไม่ Login
      print("⚠️ No active session found");
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // แสดงหน้าโหลดหมุนๆ ระหว่างรอเช็ค Role
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFA726), // สีส้มตาม Theme
        ),
      ),
    );
  }
}