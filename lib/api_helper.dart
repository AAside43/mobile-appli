import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'config.dart'; // เพื่อใช้ apiBaseUrl

class ApiHelper {
  // 1. ฟังก์ชันสำหรับสร้าง Header ที่มี Token
  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token'); // ดึง Token ที่เก็บไว้

    if (token == null) {
      throw Exception('No token found');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // นี่คือรูปแบบมาตรฐานของ JWT
    };
  }

  // 2. ตัวอย่างการเรียก API แบบ GET ที่ต้องยืนยันตัวตน
  Future<dynamic> getProfile() async {
    try {
      final headers = await _getAuthHeaders(); // 1. เอา Header มา
      final response = await http.get(
        Uri.parse('$apiBaseUrl/user/profile'), // 2. ยิง API (สมมติ path นี้)
        headers: headers, // 3. ใส่ Header
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        // 401 = Unauthorized (Token อาจหมดอายุ)
        // ที่นี่คุณต้องเขียนโค้ดให้กลับไปหน้า Login
        throw Exception('Unauthorized');
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      // จัดการ Error
      print(e);
      rethrow;
    }
  }

  // 3. ตัวอย่างการเรียก API แบบ POST
  Future<void> bookRoom(int roomId, String startTime) async {
    try {
      final headers = await _getAuthHeaders(); // 1. เอา Header มา
      final body = json.encode({
        'roomId': roomId,
        'startTime': startTime,
      });

      final response = await http.post(
        Uri.parse('$apiBaseUrl/bookings'), // 2. ยิง API
        headers: headers, // 3. ใส่ Header
        body: body,
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to book room');
      }
      // ถ้าสำเร็จก็ไม่ต้อง return อะไร
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}
