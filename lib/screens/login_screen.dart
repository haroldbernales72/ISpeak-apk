import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import 'admin_dashboard_screen.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> login() async {
    if (isLoading) return;

    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      showMessage('Please enter your username and password.');
      return;
    }

    setState(() => isLoading = true);

    try {
      // Student accounts use a synthetic email created during signup.
      // Admin and security accounts continue using their actual email.
      final loginEmail = kIsWeb
          ? username
          : '${username.toLowerCase()}@users.ispeak.local';

      await AuthService().loginUser(
        email: loginEmail,
        password: password,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage('Unable to retrieve your account. Please try again.');
        return;
      }

      final userModel = await UserService().getUser(user.uid);

      if (!mounted) return;

      if (userModel == null) {
        await AuthService().logout();

        if (!mounted) return;

        showMessage(
          'Your account profile was not found in Firestore. '
              'Check the users document ID against your Firebase Auth UID.',
        );
        return;
      }

      final role = userModel.role.trim().toLowerCase();
      final isStaff = role == 'admin' || role == 'security';
      final isStudent = role == 'student';

      debugPrint('LOGIN UID: ${user.uid}');
      debugPrint('LOGIN EMAIL: ${user.email}');
      debugPrint('FIRESTORE ROLE: "$role"');
      debugPrint('IS WEB: $kIsWeb');

      // Students use the mobile app.
      // Admin and security accounts use the website.
      final allowed = kIsWeb ? isStaff : isStudent;

      if (!allowed) {
        await AuthService().logout();

        if (!mounted) return;

        showMessage(
          kIsWeb
              ? 'Student accounts must use the mobile app.'
              : 'Admin and security accounts must use the website.',
        );
        return;
      }

      // Save the FCM token after the account role is verified.
      try {
        await NotificationService().saveTokenToFirestore();
      } catch (_) {
        // A token-saving issue should not prevent login.
      }

      if (!mounted) return;

      if (isStaff) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminDashboardScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';

      if (e.code == 'user-not-found') {
        message = kIsWeb
            ? 'No staff account was found with this email.'
            : 'No account was found with this username.';
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Incorrect username/email or password.';
      } else if (e.code == 'invalid-email') {
        message = kIsWeb
            ? 'Please enter a valid staff email address.'
            : 'Please check your username.';
      } else if (e.code == 'network-request-failed') {
        message = 'Please check your internet connection.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      }

      showMessage(message);
    } catch (_) {
      showMessage(
        'Something went wrong. Please check your connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> resetPassword() async {
    // Student usernames do not have a real email address for password resets.
    if (!kIsWeb) {
      showMessage(
        'Please contact your administrator to reset your password.',
      );
      return;
    }

    final email = usernameController.text.trim();

    if (email.isEmpty) {
      showMessage('Enter your staff email address first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      showMessage(
        'If an account exists for this email, a password reset link has been sent.',
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Unable to send the password reset email.';

      if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'network-request-failed') {
        message = 'Please check your internet connection.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }

      showMessage(message);
    } catch (_) {
      showMessage('Something went wrong. Please try again.');
    }
  }

  InputDecoration fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.umBlue),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.umBlue,
          width: 1.7,
        ),
      ),
    );
  }

  Widget buildBrand() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.umBlue,
            borderRadius: BorderRadius.circular(23),
            boxShadow: [
              BoxShadow(
                color: AppColors.umBlue.withValues(alpha: 0.20),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Icon(
            Icons.campaign_rounded,
            size: 43,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'ISpeak',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.umDarkBlue,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'UM School Safety & Incident Reporting',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.grey,
          ),
        ),
      ],
    );
  }

  Widget buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            color: AppColors.umDarkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          kIsWeb
              ? 'Sign in with your staff account to continue.'
              : 'Sign in with your username to continue.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.grey,
          ),
        ),
        const SizedBox(height: 28),

        Text(
          kIsWeb ? 'Staff Email' : 'Username',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 9),

        TextField(
          controller: usernameController,
          keyboardType:
          kIsWeb ? TextInputType.emailAddress : TextInputType.text,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          decoration: fieldDecoration(
            hint: kIsWeb ? 'Enter your staff email' : 'Enter your username',
            icon: kIsWeb ? Icons.email_outlined : Icons.person_outline,
          ),
        ),

        const SizedBox(height: 21),

        const Text(
          'Password',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 9),

        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => login(),
          decoration: fieldDecoration(
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.grey,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: isLoading ? null : resetPassword,
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.umBlue,
              ),
            ),
          ),
        ),

        const SizedBox(height: 15),

        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: isLoading ? null : login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.umBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
              AppColors.umBlue.withValues(alpha: 0.6),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SIGN IN',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),

        // Public registration is only available in the mobile app.
        if (!kIsWeb) ...[
          const SizedBox(height: 23),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Flexible(
                child: Text(
                  "Don't have an account? ",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.grey,
                  ),
                ),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.umBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 22,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: isWide
                      ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildBrand(),
                              const SizedBox(height: 35),
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: AppColors.umLightBlue,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.health_and_safety_outlined,
                                      size: 58,
                                      color: AppColors.umBlue,
                                    ),
                                    SizedBox(height: 15),
                                    Text(
                                      'A Safer Campus Starts With You',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.umDarkBlue,
                                      ),
                                    ),
                                    SizedBox(height: 9),
                                    Text(
                                      'Report incidents, follow case updates, '
                                          'and help keep the UM community safe.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        height: 1.6,
                                        fontSize: 14,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 25),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(34),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.borderGrey,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: buildLoginForm(),
                        ),
                      ),
                    ],
                  )
                      : Container(
                    padding: const EdgeInsets.all(23),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.borderGrey,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.035),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildBrand(),
                        const SizedBox(height: 32),
                        buildLoginForm(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}