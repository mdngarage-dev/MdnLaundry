import 'package:flutter/material.dart';
import '../main_screens.dart';

class GantiPasswordPage extends StatefulWidget {
  const GantiPasswordPage({super.key});

  @override
  State<GantiPasswordPage> createState() => _GantiPasswordPageState();
}

class _GantiPasswordPageState extends State<GantiPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _passwordLamaController = TextEditingController();
  final _passwordBaruController = TextEditingController();
  final _konfirmasiPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureLama = true;
  bool _obscureBaru = true;
  bool _obscureKonfirmasi = true;

  @override
  void dispose() {
    _passwordLamaController.dispose();
    _passwordBaruController.dispose();
    _konfirmasiPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleGantiPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordLamaController.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_passwordBaruController.text.trim());
        await user.reload();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Password berhasil diperbarui!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw "User tidak ditemukan. Silakan login ulang.";
      }
    } catch (e) {
      if (mounted) {
        String pesanError = e.toString();
        if (pesanError.contains('wrong-password')) {
          pesanError = "Password saat ini (lama) yang Anda masukkan salah.";
        } else if (pesanError.contains('weak-password')) {
          pesanError =
              "Password baru terlalu lemah. Gunakan minimal 6 karakter.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal: $pesanError"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // ✅ Adaptive background
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      "Perbarui kata sandi Anda secara berkala untuk menjaga keamanan akun data pasien.",
                      textAlign: TextAlign.center, // ✅ rata tengah
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.red, // ✅ warna merah
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(
                      label: "Password Saat Ini (Lama)",
                      controller: _passwordLamaController,
                      obscureText: _obscureLama,
                      onToggleVisibility: () =>
                          setState(() => _obscureLama = !_obscureLama),
                      validator: (v) =>
                          v!.isEmpty ? "Password lama wajib diisi" : null,
                    ),

                    _buildTextField(
                      label: "Password Baru",
                      controller: _passwordBaruController,
                      obscureText: _obscureBaru,
                      onToggleVisibility: () =>
                          setState(() => _obscureBaru = !_obscureBaru),
                      validator: (v) {
                        if (v!.isEmpty) return "Password baru wajib diisi";
                        if (v.length < 6) return "Password minimal 6 karakter";
                        if (v == _passwordLamaController.text) {
                          return "Password baru tidak boleh sama dengan password lama";
                        }
                        return null;
                      },
                    ),

                    _buildTextField(
                      label: "Konfirmasi Password Baru",
                      controller: _konfirmasiPasswordController,
                      obscureText: _obscureKonfirmasi,
                      onToggleVisibility: () => setState(
                        () => _obscureKonfirmasi = !_obscureKonfirmasi,
                      ),
                      validator: (v) {
                        if (v!.isEmpty) {
                          return "Konfirmasi password wajib diisi";
                        }
                        if (v != _passwordBaruController.text) {
                          return "Password konfirmasi tidak cocok";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleGantiPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "PERBARUI PASSWORD",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    // ✅ Warna icon & border adaptive
    final mutedColor = theme.textTheme.bodyLarge?.color?.withOpacity(0.45);

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            // ✅ Adaptive label
            style: theme.textTheme.bodyLarge?.copyWith(
              color: mutedColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            validator: validator,
            // ✅ Adaptive input text
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.lock_outline, color: mutedColor),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: mutedColor,
                ),
                onPressed: onToggleVisibility,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
              // ✅ Fill menggunakan cardColor
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                // ✅ Adaptive border color
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: kPrimary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final appBarTheme = Theme.of(context).appBarTheme;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: AppBar(
          // ✅ Judul & warna dari appBarTheme
          title: Text(
            "Setting Akun",
            style:
                appBarTheme.titleTextStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          elevation: 2,
          centerTitle: true,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: appBarTheme.foregroundColor ?? Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
      ),
    );
  }
}
