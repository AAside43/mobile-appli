import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile_appli_1/student/student_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'services/sse_service.dart';

import 'register_page.dart';
import 'student/student_home_page.dart';
import 'lecturer/lecturer_dashboard_page.dart';
import 'staff/staff_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // 2. เพิ่มตัวแปรสำหรับ API
  bool _isLoading = false;
  bool _isConnecting = true;
  String _connectionStatus = 'Connecting to server...';
  String baseUrl = apiBaseUrl; // centralized in lib/config.dart

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Searching for server...';
    });

    try {
      final serverIp = await getServerIp();
      if (mounted) {
        setState(() {
          baseUrl = 'http://$serverIp:3000';
          _connectionStatus = 'Connected to $serverIp';
          _isConnecting = false;
        });
        print('✅ Server found at: $baseUrl');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = 'Connection failed. Using default.';
          _isConnecting = false;
        });
        print('❌ Connection error: $e');
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  // 3. แก้ไขฟังก์ชัน Login ทั้งหมด
  Future<void> _login() async {
    if (_studentIdController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both User ID and Password."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    print('🔐 Attempting login to: $baseUrl/login');
    print('📝 Username: ${_studentIdController.text}');

    try {
      final response = await http
          .post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _studentIdController.text, // ✔ ตรงกับ backend
          'password': _passwordController.text,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout → Cannot reach server ($baseUrl/login)');
        },
      );

      print('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ Login Response: $data");
        print("👤 Role: ${data['role']}");

        final prefs = await SharedPreferences.getInstance();

        // ตรวจสอบว่ามีข้อมูลหรือไม่ก่อนบันทึก
        if (data['userId'] != null) {
          await prefs.setInt('userId', data['userId']);
        }

        await prefs.setString('role', data['role'] ?? 'student');
        await prefs.setBool('isLoggedIn', true);

        if (data['token'] != null) {
          await prefs.setString('token', data['token']);
        } else {
          throw Exception("Token is missing from server response");
        }
        
        // Connect to SSE for real-time updates
        try {
          await sseService.connect();
          print("🔌 Connected to real-time updates");
        } catch (e) {
          print("⚠️ SSE connection failed: $e");
        }

        if (!mounted) return;

        // เลือกหน้าแรกตาม role
        if (data['role'] == 'student') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentHomePage()),
          );
        } else if (data['role'] == 'lecturer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LecturerDashboardPage()),
          );
        } else if (data['role'] == 'staff') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
          );
        } else {
          print('⚠️ Unknown role, redirecting to login');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      } else {
        print('❌ Login failed with status: ${response.statusCode}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login failed: ${response.body}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      print('❌ Login error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cannot connect → $baseUrl/login\n$e"),
          backgroundColor: Colors.grey,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // (... โค้ดส่วน Image และ Title เหมือนเดิม ...)
                const SizedBox(height: 40),

                // ===== IMAGE =====
                Center(
                  child: Image.asset(
                    'assets/images/room_booking.png',
                    height: 180,
                  ),
                ),
                const SizedBox(height: 30),

                // ===== TITLE =====
                const Text(
                  "Study Room",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E7BFA),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Reservations System",
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFFFFA726),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),

                // ===== CONNECTION STATUS =====
                if (_isConnecting)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _connectionStatus,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _connectionStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // ( ... โค้ดส่วน User ID และ Password เหมือนเดิม ...)
                // ===== USER ID =====
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _studentIdController,
                    decoration: const InputDecoration(
                      hintText: "Student/User ID",
                      prefixIcon: Icon(Icons.person_outline),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ===== PASSWORD =====
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: _togglePasswordVisibility,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // ===== LOGIN BUTTON =====
                SizedBox(
                  width: 180,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isConnecting) ? null : _login, // Disable while connecting or loading
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA726),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    // 7. แสดงตัวหมุนขณะโหลด
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "LOGIN",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ( ... โค้ดส่วน Divider และ Register link เหมือนเดิม ...)
                // ===== OR DIVIDER =====
                const Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey,
                        thickness: 0.5,
                        endIndent: 10,
                      ),
                    ),
                    Text(
                      "or",
                      style: TextStyle(color: Colors.grey),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey,
                        thickness: 0.5,
                        indent: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ===== REGISTER LINK =====
                const Text(
                  "Don’t have an account?",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegisterPage()),
                    );
                  },
                  child: const Text(
                    "Register",
                    style: TextStyle(
                      color: Color(0xFF3E7BFA),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
