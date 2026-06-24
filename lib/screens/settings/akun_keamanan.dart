import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../main_screens.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _namaController;
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();

  User? _currentUser;
  bool _isLoading = false;

  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _namaController = TextEditingController(
      text: (_currentUser?.displayName ?? '').split('|')[0].trim(),
    );
    _emailController = TextEditingController(text: _currentUser?.email ?? '');
    _loadSavedProfileImage();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_pic_local.png';
      final file = File(imagePath);
      if (await file.exists()) {
        setState(() => _imageFile = file);
      }
    } catch (e) {
      print("Gagal memuat gambar lokal: $e");
    }
  }

  Future<void> _pickAndSaveImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final directory = await getApplicationDocumentsDirectory();
        final savedImagePath = '${directory.path}/profile_pic_local.png';
        final File localImage = File(pickedFile.path);
        await localImage.copy(savedImagePath);
        setState(() => _imageFile = File(savedImagePath));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Foto profil berhasil disimpan di memori HP!"),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal menyimpan foto: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfil() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_currentUser != null) {
        bool isNamaBerubah =
            _namaController.text.trim() != _currentUser!.displayName;
        bool isEmailBerubah =
            _emailController.text.trim() != _currentUser!.email;

        if (isNamaBerubah) {
          await _currentUser!.updateDisplayName(_namaController.text.trim());
        }

        if (isEmailBerubah) {
          String passwordLama = _passwordController.text.trim();
          if (passwordLama.isEmpty) {
            throw "Wajib memasukkan Password Saat Ini untuk keamanan mengubah email.";
          }
          AuthCredential credential = EmailAuthProvider.credential(
            email: _currentUser!.email!,
            password: passwordLama,
          );
          await _currentUser!.reauthenticateWithCredential(credential);
          await _currentUser!.verifyBeforeUpdateEmail(
            _emailController.text.trim(),
          );
        }

        await _currentUser!.reload();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profil berhasil diperbarui!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal memperbarui profil: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusAkun() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();

    if (!userDoc.exists) return;

    final role = userDoc.data()?['role'] ?? '';
    final storeId = userDoc.data()?['store_id'] ?? '';

    final passwordController = TextEditingController();
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Akun"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role == 'Owner'
                  ? "⚠️ Seluruh data toko termasuk akun admin akan dihapus permanen!"
                  : "Akun Anda akan dihapus. Data transaksi tidak ikut terhapus.",
              style: TextStyle(
                color: role == 'Owner' ? Colors.red : null,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Masukkan password untuk konfirmasi",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: passwordController.text.trim(),
      );
      await _currentUser!.reauthenticateWithCredential(credential);

      if (role == 'Owner') {
        await _hapusSemuaDataToko(storeId);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .delete();
      }

      await _currentUser!.delete();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus akun: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusSemuaDataToko(String storeId) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // 1. Hapus semua dokumen di keuangan, order, pengeluaran, rak
    for (final col in ['keuangan', 'order', 'pengeluaran', 'rak']) {
      final docs = await db
          .collection(col)
          .where('store_id', isEqualTo: storeId)
          .get();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
    }

    // 2. Hapus semua outlets beserta subcollection-nya
    //    (counters, layanan, settings di dalam setiap outlet)
    final outlets = await db
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .get();
    for (final outlet in outlets.docs) {
      // Hapus counters dalam outlet
      final counters = await outlet.reference.collection('counters').get();
      for (final doc in counters.docs) {
        batch.delete(doc.reference);
      }
      // Hapus layanan dalam outlet
      final layanan = await outlet.reference.collection('layanan').get();
      for (final doc in layanan.docs) {
        batch.delete(doc.reference);
      }
      // Hapus settings dalam outlet
      final settings = await outlet.reference.collection('settings').get();
      for (final doc in settings.docs) {
        batch.delete(doc.reference);
      }
      // Hapus outlet itu sendiri
      batch.delete(outlet.reference);
    }

    // 3. Hapus dokumen stores/{storeId}
    batch.delete(db.collection('stores').doc(storeId));

    // 4. Flag akun admin (store_id sama) sebagai isDeleted
    //    (tidak bisa hapus Firebase Auth akun lain dari client)
    final adminDocs = await db
        .collection('users')
        .where('store_id', isEqualTo: storeId)
        .where('role', isEqualTo: 'Admin')
        .get();
    for (final doc in adminDocs.docs) {
      batch.update(doc.reference, {'isDeleted': true});
    }

    // 5. Hapus dokumen owner sendiri
    batch.delete(db.collection('users').doc(_currentUser!.uid));

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: isDark
                                ? Colors.blue.shade900
                                : Colors.blue.shade50,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                            child: _imageFile == null
                                ? Text(
                                    (_currentUser?.displayName ?? 'U')
                                            .isNotEmpty
                                        ? (_currentUser?.displayName ?? 'U')[0]
                                              .toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: kPrimary,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: kPrimary,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                onPressed: _pickAndSaveImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(
                      label: "Nama Lengkap",
                      controller: _namaController,
                      icon: Icons.person_outline,
                      validator: (v) =>
                          v!.isEmpty ? "Nama tidak boleh kosong" : null,
                    ),

                    _buildTextField(
                      label: "Alamat Email",
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v!.isEmpty ? "Email tidak boleh kosong" : null,
                    ),

                    _buildTextField(
                      label: "Password Saat Ini (Wajib diisi jika ubah email)",
                      controller: _passwordController,
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _updateProfil,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "SIMPAN PERUBAHAN",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _hapusAkun,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "HAPUS AKUN",
                          style: TextStyle(
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
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            validator: validator,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
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
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: AppBar(
          title: Text(
            "Akun & Keamanan",
            style:
                Theme.of(context).appBarTheme.titleTextStyle ??
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
                    color:
                        Theme.of(context).appBarTheme.foregroundColor ??
                        Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
      ),
    );
  }
}
