import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'screens.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  Widget _buildGroupedMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // ✅ THEME: Warna background icon mengikuti tema
          color: Theme.of(context).primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          // ✅ THEME: Warna icon mengikuti primaryColor tema
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          // ✅ THEME: Warna teks judul mengikuti tema
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          // ✅ THEME: Warna subtitle mengikuti tema
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        // ✅ THEME: Warna chevron mengikuti tema
        color: Theme.of(context).hintColor,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      // ✅ THEME: Warna divider mengikuti tema
      color: Theme.of(context).dividerColor.withOpacity(0.5),
      indent: 56,
      endIndent: 16,
    );
  }

  Future<File?> _loadLocalProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_pic_local.png';
      final file = File(imagePath);
      if (await file.exists()) return file;
    } catch (e) {
      print("Gagal memuat gambar di settings: $e");
    }
    return null;
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
      await prefs.setBool('auto_relogin', false);
      await prefs.remove('last_active_timestamp');
      await prefs.remove('auth_uid');

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GetStartedScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal Keluar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ THEME: Latar belakang mengikuti tema global
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        // ✅ THEME: Menggunakan appBarTheme global (warna, elevasi, shape sudah di tema)
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        // ✅ THEME: Warna AppBar mengikuti appBarTheme.backgroundColor
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Card Profil Utama ─────────────────────────────────────────
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(
                  20,
                ), // Disamakan dengan radius Container agar efek klik tidak luber
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // ✅ THEME: Warna card mengikuti tema
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      // ✅ THEME: Warna border mengikuti dividerColor tema
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.3
                              : 0.02,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      FutureBuilder<File?>(
                        future: _loadLocalProfileImage(),
                        builder: (context, snapshot) {
                          final localImageFile = snapshot.data;
                          return CircleAvatar(
                            radius: 30,
                            // ✅ THEME: Background avatar mengikuti primaryColor
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            backgroundImage: localImageFile != null
                                ? FileImage(localImageFile)
                                : null,
                            child: localImageFile == null
                                ? Text(
                                    (FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.displayName ??
                                            'User')[0]
                                        .toUpperCase(),
                                    style: TextStyle(
                                      // ✅ THEME: Warna teks inisial mengikuti primaryColor
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (FirebaseAuth.instance.currentUser?.displayName ??
                                      'User')
                                  .split('|')[0]
                                  .trim(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                // ✅ THEME: Warna nama mengikuti tema
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                // ✅ THEME: Warna badge mengikuti primaryColor
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Super Admin",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  // ✅ THEME: Warna teks badge mengikuti primaryColor
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              Text(
                "Akun & Keamanan",
                style: TextStyle(
                  // ✅ THEME: Warna label section mengikuti tema
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // ── Grup Menu ─────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  // ✅ THEME: Warna card grup menu mengikuti tema
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      _buildGroupedMenuItem(
                        context: context,
                        icon: Icons.person_outline,
                        title: "Akun & Keamanan",
                        subtitle: "Ubah nama, foto, dan info pribadi",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilPage(),
                            ),
                          ).then((_) {
                            (context as Element).markNeedsBuild();
                          });
                        },
                      ),
                      _buildDivider(context),
                      _buildGroupedMenuItem(
                        context: context,
                        icon: Icons.store_outlined,
                        title: "Kelola Outlet",
                        subtitle: "Nama, Alamat, No. HP, dan Logo Outlet",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OutletPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(context),
                      _buildGroupedMenuItem(
                        context: context,
                        icon: Icons.lock_outline,
                        title: "Ganti Password",
                        subtitle: "Perbarui kata sandi secara berkala",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GantiPasswordPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(context),
                      _buildGroupedMenuItem(
                        context: context,
                        icon: Icons.dark_mode_outlined,
                        title: "Mode Warna",
                        subtitle: "Gelap, terang, sistem",
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            // ✅ THEME: BottomSheet mengikuti warna card tema
                            backgroundColor: Theme.of(context).cardColor,
                            builder: (context) {
                              final themeProvider = Provider.of<ThemeProvider>(
                                context,
                                listen: false,
                              );
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 10,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        "Pilih Mode Warna",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          // ✅ THEME: Warna judul bottomsheet mengikuti tema
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.wb_sunny_outlined,
                                        color: Colors.orange,
                                      ),
                                      title: const Text("Terang"),
                                      trailing:
                                          themeProvider.themeMode ==
                                              ThemeMode.light
                                          ? Icon(
                                              Icons.check_circle,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            )
                                          : null,
                                      onTap: () {
                                        themeProvider.changeTheme(
                                          ThemeMode.light,
                                        );
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.nightlight_round_outlined,
                                        color: Colors.blue,
                                      ),
                                      title: const Text("Gelap"),
                                      trailing:
                                          themeProvider.themeMode ==
                                              ThemeMode.dark
                                          ? Icon(
                                              Icons.check_circle,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            )
                                          : null,
                                      onTap: () {
                                        themeProvider.changeTheme(
                                          ThemeMode.dark,
                                        );
                                        Navigator.pop(context);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.brightness_auto_outlined,
                                        color: Colors.grey,
                                      ),
                                      title: const Text("Ikuti Sistem HP"),
                                      trailing:
                                          themeProvider.themeMode ==
                                              ThemeMode.system
                                          ? Icon(
                                              Icons.check_circle,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            )
                                          : null,
                                      onTap: () {
                                        themeProvider.changeTheme(
                                          ThemeMode.system,
                                        );
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      _buildDivider(context),
                      _buildGroupedMenuItem(
                        context: context,
                        icon: Icons.info_outline,
                        title: "Tentang Aplikasi",
                        subtitle: "Versi ${AppConfig.appVersion} - Klinik Ku",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TentangAplikasiPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Tombol Sign Out ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    "SIGN OUT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // ✅ THEME: Warna dialog mengikuti cardColor tema
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            "Konfirmasi",
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          content: Text(
            "Apakah Anda yakin ingin keluar dari ${OutletSettings.namaKlinik}?",
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Batal",
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _handleSignOut(context);
              },
              child: const Text(
                "Ya, Keluar",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
