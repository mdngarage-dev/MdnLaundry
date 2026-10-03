import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  bool _remember = true;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('saved_email') ?? '';
      _passwordController.text = prefs.getString('saved_password') ?? '';
      _remember = prefs.getBool('remember_me') ?? false;
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_remember) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setString('saved_password', _passwordController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
      await prefs.setBool('auto_relogin', true);
    }
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Email dan Password tidak boleh kosong", isError: true);
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          // Get user data dari Firestore
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          final userData = userDoc.data() ?? {};
          final isDeleted = userData['isDeleted'] ?? false;
          final isAppOwner = userData['is_app_owner'] ?? false;
          final role = userData['role'] ?? '';

          // Cek apakah akun sudah di-delete
          if (isDeleted == true) {
            await FirebaseAuth.instance.signOut();
            _showSnackBar(
              "Akun Anda telah dinonaktifkan oleh pemilik toko.",
              isError: true,
            );
            return;
          }

          // ── DEVELOPER (is_app_owner = true) → Skip email verification ──
          if (isAppOwner || role == 'Developer') {
            await _saveCredentials();
            await saveLastActiveTime();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_uid', user.uid);

            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeWrapper()),
                (route) => false,
              );
            }
            return;
          }

          // ── OWNER & ADMIN → Enforce email verification ──────────────────
          if (!user.emailVerified) {
            await FirebaseAuth.instance.signOut();
            _showSnackBar(
              "Email belum diverifikasi. Cek kotak masuk atau folder spam Anda.",
              isError: true,
            );
            return;
          }

          // Email verified → proceed to home
          await _saveCredentials();
          await saveLastActiveTime();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_uid', user.uid);

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeWrapper()),
              (route) => false,
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "Terjadi kesalahan";
      if (e.code == 'user-not-found') message = "Email tidak terdaftar";
      if (e.code == 'wrong-password') message = "Password salah";
      if (e.code == 'invalid-email') message = "Format email salah";
      if (e.code == 'invalid-credential') message = "Email atau password salah";
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar("Login Gagal: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              IconButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/getstarted', (route) => false);
                },
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: Theme.of(context).textTheme.bodyLarge?.color,
                padding: EdgeInsets.zero,
              ),

              Center(
                child: Image.asset(
                  'assets/images/signin.png',
                  width: MediaQuery.of(context).size.width * 0.6,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 28),

              Text(
                "Welcome Back 👋",
                style: TextStyle(
                  fontFamily: 'BubbbleGum',
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Sign in to continue your work.",
                style: TextStyle(
                  fontFamily: 'Pastrami',
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),

              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: customInputDecoration(
                        context: context,
                        hint: 'Email',
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePass,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: customInputDecoration(
                        context: context,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Theme.of(context).hintColor,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _remember,
                              onChanged: (v) =>
                                  setState(() => _remember = v ?? false),
                              activeColor: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Text(
                              'Remember me',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoggingIn ? null : _handleSignIn,
                        style: primaryButtonStyle(),
                        child: _isLoggingIn
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
