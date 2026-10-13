import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  String _selectedCampus = 'Digos';

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _campuses = [
    'Davao',
    'Digos',
    'Tagum',
    'Panabo',
    'Bansalan',
    'Peñaplata',
  ];

  String _authEmailFromUsername(String username) {
    return '${username.trim().toLowerCase()}@users.ispeak.local';
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : AppColors.danger,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _signUp() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    if (kIsWeb) {
      _showMessage('Registration is available only in the mobile app.');
      return;
    }

    setState(() => _isLoading = true);

    User? createdAuthUser;
    bool profileSaved = false;

    try {
      final username = _usernameController.text.trim().toLowerCase();
      final authEmail = _authEmailFromUsername(username);

      final firestore = FirebaseFirestore.instance;

      // Create the Firebase Authentication account.
      final UserCredential credential =
      await _authService.registerUser(
        email: authEmail,
        password: _passwordController.text,
      );

      final User? authUser = credential.user;

      if (authUser == null) {
        _showMessage(
          'Firebase did not return a user account. Please try again.',
        );
        return;
      }

      createdAuthUser = authUser;

      // Create the profile. The default role is always student.
      final newUser = UserModel(
        uid: authUser.uid,
        name: _nameController.text.trim(),
        email: authEmail,
        studentId: _studentIdController.text.trim(),
        campus: _selectedCampus,
        role: 'student',
        createdAt: DateTime.now(),
      );

      await _userService.createUser(newUser);
      profileSaved = true;

      // Save the username in the same user document.
      await firestore.collection('users').doc(authUser.uid).update({
        'username': username,
      });

      if (!mounted) return;

      _showMessage(
        'Account created successfully! Please log in.',
        success: true,
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('SIGNUP AUTH ERROR CODE: ${e.code}');
      debugPrint('SIGNUP AUTH ERROR MESSAGE: ${e.message}');
      debugPrintStack(stackTrace: stackTrace);

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This username may already be registered.';
          break;
        case 'weak-password':
          message = 'Please use a stronger password.';
          break;
        case 'invalid-email':
          message = 'The generated account address is invalid.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        case 'operation-not-allowed':
          message =
          'Email/password sign-in is disabled in Firebase Authentication.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = 'Firebase error (${e.code}): '
              '${e.message ?? 'Unable to create the account.'}';
      }

      // Delete the Auth account only if profile creation failed.
      // If the profile exists, preserve the account for recovery.
      if (createdAuthUser != null && !profileSaved) {
        try {
          await createdAuthUser.delete();
        } catch (cleanupError) {
          debugPrint('AUTH CLEANUP ERROR: $cleanupError');
        }
      }

      _showMessage(message);
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('SIGNUP FIREBASE ERROR CODE: ${e.code}');
      debugPrint('SIGNUP FIREBASE ERROR MESSAGE: ${e.message}');
      debugPrintStack(stackTrace: stackTrace);

      String message;

      if (e.code == 'permission-denied') {
        message =
        'Firebase denied access to the user profile. Check Firestore rules.';
      } else if (e.code == 'unavailable') {
        message =
        'Firebase is temporarily unavailable. Check your connection and try again.';
      } else if (e.code == 'already-exists') {
        message = 'This user record already exists.';
      } else {
        message = 'Firebase error (${e.code}): '
            '${e.message ?? 'Unable to save your account.'}';
      }

      // Do not automatically delete the account here.
      // Firestore may have saved the profile before a later operation failed.
      _showMessage(message);
    } catch (e, stackTrace) {
      debugPrint('SIGNUP UNEXPECTED ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      final error = e.toString();

      if (error.contains('username-already-in-use')) {
        _showMessage('That username is already taken. Choose another.');
      } else {
        _showMessage('Registration failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Registration is available only in the mobile app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.umBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Create Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 70,
                          width: 70,
                          decoration: BoxDecoration(
                            color: AppColors.umLightBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.umBlue,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Join ISpeak',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: AppColors.umDarkBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create an account to report safety concerns '
                              'and monitor your reports.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.grey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        _buildLabel('Full Name'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                            hint: 'Enter your full name',
                            icon: Icons.person_outline,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your full name.';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        _buildLabel('Student ID / Client ID'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _studentIdController,
                          decoration: _inputDecoration(
                            hint: 'Enter your ID',
                            icon: Icons.badge_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your ID.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        _buildLabel('Username'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _usernameController,
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          decoration: _inputDecoration(
                            hint: 'Choose a username',
                            icon: Icons.alternate_email,
                          ),
                          validator: (value) {
                            final username = value?.trim() ?? '';

                            if (username.isEmpty) {
                              return 'Please choose a username.';
                            }
                            if (username.length < 4) {
                              return 'Username must be at least 4 characters.';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9._]+$')
                                .hasMatch(username)) {
                              return 'Use letters, numbers, dots, '
                                  'or underscores only.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        _buildLabel('Campus'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCampus,
                          isExpanded: true,
                          decoration: _inputDecoration(
                            hint: 'Select your campus',
                            icon: Icons.location_on_outlined,
                          ),
                          items: _campuses.map((campus) {
                            return DropdownMenuItem<String>(
                              value: campus,
                              child: Text(campus),
                            );
                          }).toList(),
                          onChanged: _isLoading
                              ? null
                              : (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCampus = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 18),

                        _buildLabel('Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            hint: 'Create a password',
                            icon: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please create a password.';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        _buildLabel('Confirm Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: _inputDecoration(
                            hint: 'Re-enter your password',
                            icon: Icons.lock_reset_outlined,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password.';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.umBlue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                              AppColors.umBlue.withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                              child: Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.grey,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text(
                                'Log In',
                                style: TextStyle(
                                  color: AppColors.umBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.grey),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.umBlue,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}