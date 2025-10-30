/*// Required Flutter material components for UI elements
import 'package:flutter/material.dart';
// Authentication service for handling login/logout operations
import 'package:test_the_app/services/auth_service.dart';
// Configuration service for managing server endpoints and settings
import 'package:test_the_app/services/config_service.dart';
// Room list page for navigation after login
import 'roomlist.dart';

// Main login screen widget providing:
// - Form validation for email and password
// - Server authentication integration
// - Loading state management
// - Error handling with SnackBar notifications
// - Visual feedback for user interactions
// Stateful widget for the login page that maintains form state
class LoginPage extends StatefulWidget {
  // Optional callback triggered after successful login
  final VoidCallback? onLoginSuccess;

  // Constructor with named parameters
  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// Private state class handling the login form logic
class _LoginPageState extends State<LoginPage> {
  // Demo credentials for testing purposes
  static const _demoEmail = 'test@example.com';
  static const _demoPassword = 'password';

  // Form key for validation and form state management
  final _formKey = GlobalKey<FormState>();

  // Controllers for the text input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Service instances for server communication
  final AuthService _authService = AuthService();
  final ConfigService _configService = ConfigService();

  // JWT token received from server after successful authentication
  String? _authToken;

  // UI state flags
  bool _obscurePassword = true; // Controls password visibility
  bool _loading = false; // Tracks authentication in progress

  // Called when widget is first created
  @override
  void initState() {
    super.initState();
    // Load server configuration on startup
    _initializeConfig();
  }

  // Initialize server configuration from assets
  Future<void> _initializeConfig() async {
    try {
      await _configService.initialize();
    } catch (e) {
      // Only show error if widget is still mounted
      if (mounted) {
        _showMessage('Failed to load configuration: $e');
      }
    }
  }

  // Clean up resources when widget is removed
  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    // Clean up authentication service
    _authService.dispose();
    super.dispose();
  }

  // Validate email format using regular expression
  String? _validateEmail(String? value) {
    // Check for empty or null value
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    // Trim whitespace and validate format
    final email = value.trim();
    // Match pattern: something@domain.tld
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)) {
      return 'Enter a valid email';
    }

    return null; // Return null for valid input
  }

  // Validate password meets minimum requirements
  String? _validatePassword(String? value) {
    // Check for empty or null value
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    // Check minimum length requirement
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null; // Return null for valid input
  }

  // Attempt to authenticate with the server
  Future<bool> _authenticate(String email, String password) async {
    try {
      // Call auth service and store the returned token
      _authToken = await _authService.login(email, password);
      return true; // Authentication successful
    } catch (e) {
      // Show error message on failure
      _showMessage('Authentication failed: $e');
      return false; // Authentication failed
    }
  }

  // Display feedback messages to user via SnackBar
  void _showMessage(String text, {bool success = false}) {
    // Check if widget is still mounted to avoid errors
    if (!mounted) return;

    // Create and show SnackBar with improved styling
    final snack = SnackBar(
      content: Text(text, style: const TextStyle(fontSize: 16)),
      backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(8),
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  // Handle form submission and authentication
  Future<void> _submit() async {
    // First validate all form fields
    // Returns true if all validators return null
    if (!(_formKey.currentState?.validate() ?? false)) {
      return; // Stop if validation fails
    }

    // Show loading spinner while processing
    setState(() => _loading = true);

    // Get user input, trimming email whitespace
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Attempt server authentication
    final ok = await _authenticate(email, password);

    // Ensure widget is still mounted before updating UI
    if (!mounted) return;
    // Hide loading spinner
    setState(() => _loading = false);

    if (ok) {
      // On success: show success message
      _showMessage('Login successful', success: true);
      // Brief delay to show success message before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        // Navigate to room list page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RoomListPage(authToken: _authToken!),
          ),
        );
      }
      // Trigger navigation callback if provided
      widget.onLoginSuccess?.call();
    } else {
      // On failure: show error message
      _showMessage('Invalid email or password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FlutterLogo(size: 88),
                const SizedBox(height: 20),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          // Email input field with validation
                          TextFormField(
                            enabled: !_loading, // Disable during authentication
                            controller: _emailController, // Control text input
                            textInputAction:
                                TextInputAction.next, // Show next key
                            decoration: const InputDecoration(
                              labelText: 'Email', // Field label
                              prefixIcon: Icon(Icons.email), // Email icon
                            ),
                            keyboardType:
                                TextInputType.emailAddress, // Email keyboard
                            validator: _validateEmail, // Validate input
                            onFieldSubmitted: (_) => FocusScope.of(
                              context,
                            ).nextFocus(), // Move to password
                          ),
                          const SizedBox(height: 12),
                          // Password input field with toggle visibility
                          TextFormField(
                            enabled: !_loading, // Disable during authentication
                            controller:
                                _passwordController, // Control text input
                            textInputAction:
                                TextInputAction.done, // Show done key
                            decoration: InputDecoration(
                              labelText: 'Password', // Field label
                              prefixIcon: const Icon(Icons.lock), // Lock icon
                              suffixIcon: IconButton(
                                // Show/hide password button
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons
                                            .visibility // Eye icon when hidden
                                      : Icons
                                            .visibility_off, // Crossed eye when shown
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword =
                                      !_obscurePassword, // Toggle visibility
                                ),
                              ),
                            ),
                            obscureText:
                                _obscurePassword, // Hide password when true
                            validator: _validatePassword, // Validate input
                            onFieldSubmitted: (_) =>
                                _submit(), // Submit on done
                          ),
                          const SizedBox(height: 18),
                          // Submit button with loading state
                          SizedBox(
                            width: double.infinity, // Full width button
                            height: 44, // Fixed height for consistent look
                            child: ElevatedButton(
                              onPressed: _loading
                                  ? null
                                  : _submit, // Disable while loading
                              child: _loading
                                  ? Row(
                                      // Show loading indicator when authenticating
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Signing in...'),
                                      ],
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Demo credentials button
                          TextButton(
                            onPressed: _loading
                                ? null // Disable during authentication
                                : () {
                                    // Fill form with demo credentials
                                    _emailController.text = _demoEmail;
                                    _passwordController.text = _demoPassword;
                                  },
                            child: const Text('Use demo credentials'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Help text for demo users
                const Text(
                  'Don\'t have an account? This demo is read-only. Use the demo credentials above.',
                  textAlign: TextAlign.center, // Center align help text
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}*/

