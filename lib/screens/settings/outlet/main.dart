import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mdnlaundry_project/screens/screens.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class OutletSettingScreen extends StatelessWidget {
  const OutletSettingScreen({super.key});

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
          "Outlet Setting",
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
                        icon: Icons.print_disabled_outlined,
                        title: "Printer Setting",
                        subtitle: "Ubah Fotter & Header Printer",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrinterSettingPage(),
                            ),
                          ).then((_) {
                            (context as Element).markNeedsBuild();
                          });
                        },
                      ),

                      _buildDivider(context),

                      // Menu yang hanya muncul untuk owner (hanya Admin yang diizinkan)
                      FutureBuilder<bool>(
                        future: canAccess('can_access_layanan'),
                        builder: (context, snapshot) {
                          if (!(snapshot.data ?? false)) {
                            return const SizedBox.shrink();
                          }
                          return _buildGroupedMenuItem(
                            context: context,
                            icon: Icons.local_laundry_service_outlined,
                            title: "Daftar Layanan",
                            subtitle: "Ubah Layanan Laundry",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LayananScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      _buildDivider(context),
                      _buildGroupedMenuItem(
                        context: context,
                        icon: Icons.phone_android_outlined,
                        title: "Daftar Pelanggan",
                        subtitle: "Ubah & tambah kontak pelanggan",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DaftarPelangganPage(),
                            ),
                          );
                        },
                      ),

                      _buildDivider(context),
                      // Menu yang hanya muncul untuk owner (hanya Admin yang diizinkan)
                      FutureBuilder<bool>(
                        future: canAccess('can_access_outlet'),
                        builder: (context, snapshot) {
                          if (!(snapshot.data ?? false)) {
                            return const SizedBox.shrink();
                          }
                          return _buildGroupedMenuItem(
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
                          );
                        },
                      ),

                      _buildDivider(context),
                      // Menu yang hanya muncul untuk owner (hanya Admin yang diizinkan)
                      FutureBuilder<bool>(
                        future: canAccess('can_access_admin'),
                        builder: (context, snapshot) {
                          if (!(snapshot.data ?? false)) {
                            return const SizedBox.shrink();
                          }
                          return _buildGroupedMenuItem(
                            context: context,
                            icon: Icons.admin_panel_settings_outlined,
                            title: "Kelola Admin",
                            subtitle: "Izin & Kelola Akses admin",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ManageAdminAccessScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
