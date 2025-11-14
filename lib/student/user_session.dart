// Simple user session management
class UserSession {
  static int? _userId;
  static String? _username;
  static String? _role;

  static void setUser(int userId, String username, String role) {
    _userId = userId;
    _username = username;
    _role = role;
  }

  static int? get userId => _userId;
  static String? get username => _username;
  static String? get role => _role;

  static bool get isStudent => _role == 'student';
  static bool get isStaff => _role == 'staff';
  static bool get isLecturer => _role == 'lecturer';

  static void clear() {
    _userId = null;
    _username = null;
    _role = null;
  }
}
