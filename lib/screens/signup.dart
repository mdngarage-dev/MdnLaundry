import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'screens.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _agreed = false;
  bool _obscurePass = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillNameFromGoogle();
  }

  // ── Ambil Nama dari Akun Google Device (tanpa popup) ─────────────────────
  Future<void> _prefillNameFromGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final account = await googleSignIn.signInSilently();
      if (account != null && mounted) {
        setState(() {
          _nameController.text = account.displayName ?? '';
          _emailController.text = account.email;
        });
      }
    } catch (e) {
      debugPrint("Gagal ambil nama Google: $e");
    }
  }

  // ── Sign Up Email & Password ──────────────────────────────────────────────
  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("Semua kolom harus diisi!", isError: true);
      return;
    }
    if (!_agreed) {
      _showSnackBar("Anda harus menyetujui privacy policy", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String fullUrl = "$baseAppScriptUrl?action=getStats";
      final response = await http.get(Uri.parse(fullUrl));
      String generatedNip = "AdmMc-005";

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['status'] == 'ok') {
          int totalPasienSekarang =
              responseData['stats']['total_pasien_bulan_ini'] ?? 0;
          int urutanBerikutnya = totalPasienSekarang + 10;
          String nomorPad = urutanBerikutnya.toString().padLeft(3, '0');
          generatedNip = "AdmMc-$nomorPad";
        }
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await userCredential.user?.updateDisplayName("$name|$generatedNip");
      await saveLastActiveTime();
      if (userCredential.user != null) {
        await userCredential.user!.sendEmailVerification();
      }

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        _showSnackBar(
          "Registrasi sukses (NIP: $generatedNip). Silakan cek EMAIL Anda untuk verifikasi akun sebelum login!",
          isError: false,
        );
        // Tunggu sebentar agar snackbar kebaca, baru arahkan ke login
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/login',
          ); // atau '/login' sesuai route kamu
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "Terjadi kesalahan";
      if (e.code == 'weak-password') {
        message = "Password terlalu lemah";
      } else if (e.code == 'email-already-in-use')
        message = "Email sudah digunakan";
      else if (e.code == 'invalid-email')
        message = "Format email salah";
      _showSnackBar(message, isError: true);
    } catch (e) {
      _showSnackBar("Gagal daftar: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Sign Up / Sign In dengan Google ──────────────────────────────────────
  Future<void> _handleGoogleSignUp() async {
    if (!_agreed) {
      _showSnackBar("Anda harus menyetujui privacy policy dulu", isError: true);
      return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      // Kalau user baru (belum punya displayName) → generate NIP
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final name = googleUser.displayName ?? 'User';
        // Generate NIP sederhana untuk akun Google baru
        final nip = "AdmMc-G${DateTime.now().millisecondsSinceEpoch % 1000}";
        await userCredential.user?.updateDisplayName("$name|$nip");
        _showSnackBar("Akun berhasil dibuat dengan NIP: $nip", isError: false);
      }

      await saveLastActiveTime();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar("Google Sign Up Gagal: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
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
    _nameController.dispose();
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
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: Theme.of(context).textTheme.bodyLarge?.color,
                padding: EdgeInsets.zero,
              ),

              Center(
                child: Image.asset(
                  'assets/images/register.png',
                  width: MediaQuery.of(context).size.width * 0.6,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                "Create Account",
                style: TextStyle(
                  fontFamily: 'BubbbleGum',
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // ✅ Greeting dinamis dari nama Google
              Text(
                _nameController.text.trim().isEmpty
                    ? "Hello! Selamat Bergabung"
                    : "Hello, ${_nameController.text.trim().split(' ').first}!\nSelamat Bergabung",
                style: TextStyle(
                  fontFamily: 'Pastrami',
                  color:
                      Theme.of(context).textTheme.bodyMedium?.color ??
                      Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(20),
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
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: customInputDecoration(
                        context: context,
                        hint: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: (v) =>
                              setState(() => _agreed = v ?? false),
                          activeColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        Text(
                          'I agree with ',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            'privacy policy',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Tombol Sign Up ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_agreed)
                            ? null
                            : _handleSignUp,
                        style: primaryButtonStyle(),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Sign Up'),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Divider "atau" ────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Theme.of(context).dividerColor,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'atau',
                            style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Theme.of(context).dividerColor,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Tombol Google Sign Up ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isGoogleLoading
                            ? null
                            : _handleGoogleSignUp,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFE5E7EB),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                        ),
                        child: _isGoogleLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).primaryColor,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Lanjut dengan Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ],
                              ),
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
