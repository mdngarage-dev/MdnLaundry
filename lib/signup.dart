import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/main_screens.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _agreed = false;
  final _obscurePass = ValueNotifier<bool>(true);
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  String _selectedRole = 'Admin'; // Default role

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _namaTokoController = TextEditingController();
  final _ownerCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillNameFromGoogle();
  }

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

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final namaToko = _namaTokoController.text.trim();
    final inputCode = _ownerCodeController.text.trim();

    // 1. Validasi Standar
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("Semua kolom harus diisi!", isError: true);
      return;
    }
    if (inputCode.isEmpty) {
      _showSnackBar(
        _selectedRole == 'Owner'
            ? "Kode undangan Owner harus diisi!"
            : "Kode Toko harus diisi agar terhubung dengan Owner!",
        isError: true,
      );
      return;
    }
    if (_selectedRole == 'Owner' && namaToko.isEmpty) {
      _showSnackBar("Nama toko wajib diisi untuk Owner!", isError: true);
      return;
    }
    if (!_agreed) {
      _showSnackBar("Anda harus menyetujui privacy policy", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    String? targetStoreId;
    String cleanNamaToko = namaToko;

    try {
      // 2. Validasi Kode Berdasarkan Role SEBELUM membuat akun Auth
      if (_selectedRole == 'Owner') {
        final doc = await FirebaseFirestore.instance
            .collection('config')
            .doc('owner_code')
            .get()
            .timeout(const Duration(seconds: 10));

        final validCode = doc.data()?['code'] ?? '';
        if (inputCode != validCode) {
          _showSnackBar("Kode undangan Owner tidak valid!", isError: true);
          setState(() => _isLoading = false);
          return;
        }
      } else {
        final storeQuery = await FirebaseFirestore.instance
            .collection('stores')
            .where('kode_toko', isEqualTo: inputCode.toUpperCase())
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        if (storeQuery.docs.isEmpty) {
          _showSnackBar(
            "Kode Toko tidak ditemukan! Silakan minta ke Owner Anda.",
            isError: true,
          );
          setState(() => _isLoading = false);
          return;
        }

        targetStoreId = storeQuery.docs.first.id;
        cleanNamaToko = storeQuery.docs.first.data()['nama_toko'] ?? '';
      }

      // 3. Step Pembuatan Akun di Firebase Auth
      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password)
            .timeout(const Duration(seconds: 15));
      } on FirebaseAuthException catch (e) {
        String message = "Terjadi kesalahan";
        if (e.code == 'weak-password') {
          message = "Password terlalu lemah (min 6 karakter)";
        } else if (e.code == 'email-already-in-use') {
          message = "Email sudah digunakan";
        } else if (e.code == 'invalid-email') {
          message = "Format email salah";
        }
        _showSnackBar(message, isError: true);
        setState(() => _isLoading = false);
        return;
      }

      final String currentUid = userCredential.user!.uid;

      if (_selectedRole == 'Owner') {
        targetStoreId = currentUid;
      }

      // 4. Generate NIP acak berdasarkan role
      final ts = DateTime.now().millisecondsSinceEpoch.toString();
      final randomPart = ts.substring(ts.length - 10);
      final prefix = _selectedRole == 'Owner' ? 'OWN' : 'ADM';
      final generatedNip = '$prefix$randomPart';

      // 5. Update Profile DisplayName di Firebase Auth
      try {
        await userCredential.user
            ?.updateDisplayName(
              "$name|$generatedNip|$_selectedRole|$cleanNamaToko",
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint("updateDisplayName gagal: $e");
      }

      // 6. Simpan Profile User ke Collection 'users'
      await FirebaseFirestore.instance.collection('users').doc(currentUid).set({
        'nama': name,
        'email': email,
        'nip': generatedNip,
        'role': _selectedRole,
        'nama_toko': cleanNamaToko,
        'store_id': targetStoreId,
        'is_activated': false,
        'created_at': FieldValue.serverTimestamp(),
        if (_selectedRole == 'Owner') ...{
          'can_access_admin': true,
          'can_access_ringkasan': true,
          'can_access_harian': true,
          'can_access_lispengeluaran': true,
          'can_eit_layanan': true,
          'can_hapus_order': true,
          'can_hapus_pelanggan': true,
          'can_access_layanan': true,
          'can_access_rak': true,
          'can_access_outlet': true,
          'can_access_togle_nohp': true,
          'can_access_togle_alamat': true,
          'can_access_nota': true,
          'can_kelola_rekening': true,
          'can_access_wa_setting': true,
        },
      });

      // 7. JIKA REGISTER SEBAGAI OWNER -> Buat Toko, Outlet Utama, & Counter
      if (_selectedRole == 'Owner') {
        final randomDigits = (DateTime.now().millisecondsSinceEpoch % 900 + 100)
            .toString();
        String kodeTokoBaru = "LND$randomDigits";

        final storeRef = FirebaseFirestore.instance
            .collection('stores')
            .doc(currentUid);

        // Buat data toko induk
        await storeRef.set({
          'nama_toko': cleanNamaToko,
          'kode_toko': kodeTokoBaru.toUpperCase(),
          'owner_uid': currentUid,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Buat outlet utama dulu, lalu gunakan ID-nya untuk counter
        final outletRef = await storeRef.collection('outlets').add({
          'nama_outlet': cleanNamaToko,
          'is_utama': true,
          'alamat': '',
          'no_hp': '',
          'logo_url': '',
          'created_at': FieldValue.serverTimestamp(),
        });

        // Counter masuk ke dalam outlet yang baru dibuat
        await outletRef.collection('counters').doc('pelanggan').set({
          'last': 0,
        });

        // Simpan current_outlet_id ke dokumen user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .update({'current_outlet_id': outletRef.id});

        debugPrint(
          "Toko baru berhasil dibuat dengan Kode Akses Admin: $kodeTokoBaru",
        );
      }

      // 8. Kirim Verifikasi Email & Sign Out
      try {
        await userCredential.user!.sendEmailVerification().timeout(
          const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint("sendEmailVerification gagal: $e");
      }

      await saveLastActiveTime().catchError((_) {});
      await FirebaseAuth.instance.signOut().catchError((_) {});

      if (mounted) {
        _showSnackBar(
          "Registrasi sukses! NIP: $generatedNip\nCek EMAIL untuk verifikasi akun.",
          isError: false,
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _showSnackBar("Gagal daftar: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (!_agreed) {
      _showSnackBar("Anda harus menyetujui privacy policy dulu", isError: true);
      return;
    }
    if (_namaTokoController.text.trim().isEmpty) {
      _showSnackBar("Nama toko harus diisi terlebih dahulu", isError: true);
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

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        final name = googleUser.displayName ?? 'User';
        final namaToko = _namaTokoController.text.trim();
        final nip = "AdmLnd-G${DateTime.now().millisecondsSinceEpoch % 1000}";

        await userCredential.user?.updateDisplayName(
          "$name|$nip|$_selectedRole|$namaToko",
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'nama': name,
              'email': googleUser.email,
              'nip': nip,
              'role': _selectedRole,
              'nama_toko': namaToko,
              'created_at': FieldValue.serverTimestamp(),
            });

        _showSnackBar("Akun berhasil dibuat! NIP: $nip", isError: false);
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
    _namaTokoController.dispose();
    _obscurePass.dispose();
    _ownerCodeController.dispose();
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: customInputDecoration(
                        context: context,
                        hint: 'Nama Lengkap',
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

                    ValueListenableBuilder<bool>(
                      valueListenable: _obscurePass,
                      builder: (context, obscure, _) {
                        return TextField(
                          controller: _passwordController,
                          obscureText: obscure,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: customInputDecoration(
                            context: context,
                            hint: 'Password (min. 6 karakter)',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Theme.of(context).hintColor,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _obscurePass.value = !_obscurePass.value,
                            ),
                          ),
                        );
                      },
                    ),

                    if (_selectedRole == 'Owner') ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _ownerCodeController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: customInputDecoration(
                          context: context,
                          hint: 'Kode Undangan Owner',
                          icon: Icons.vpn_key_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (_selectedRole == 'Admin') ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _ownerCodeController,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: customInputDecoration(
                          context: context,
                          hint: 'Masukkan Kode Toko (Dari Owner Anda)',
                          icon: Icons.store_mall_directory_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (_selectedRole == 'Owner') ...[
                      TextField(
                        controller: _namaTokoController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.words,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: customInputDecoration(
                          context: context,
                          hint: 'Nama Store / Toko',
                          icon: Icons.store_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Text(
                      "Role Akun",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : kPrimaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : const Color(0xFFD4E6F5),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildRoleOption(
                            label: 'Admin',
                            icon: Icons.manage_accounts_outlined,
                            isSelected: _selectedRole == 'Admin',
                            onTap: () => setState(() {
                              _selectedRole = 'Admin';
                              _namaTokoController.clear();
                              _ownerCodeController.clear();
                            }),
                            isDark: isDark,
                          ),
                          Container(
                            width: 1,
                            height: 48,
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFD4E6F5),
                          ),
                          _buildRoleOption(
                            label: 'Owner',
                            icon: Icons.business_center_outlined,
                            isSelected: _selectedRole == 'Owner',
                            onTap: () =>
                                setState(() => _selectedRole = 'Owner'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedRole == 'Owner'
                                ? Icons.business_center_outlined
                                : Icons.manage_accounts_outlined,
                            size: 16,
                            color: kPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedRole == 'Owner'
                                  ? "Owner: Akses penuh termasuk laporan keuangan & pengaturan"
                                  : "Admin: Akses operasional harian (registrasi & menerima Orderan)",
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 11, color: kPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

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

  Widget _buildRoleOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white54 : kTextLight),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white54 : kTextLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
