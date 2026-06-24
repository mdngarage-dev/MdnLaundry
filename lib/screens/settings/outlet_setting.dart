import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mdnlaundry_project/screens/settings/outlet/wa_settings.dart';

class OutletSettingScreen extends StatelessWidget {
  final String storeId;
  final String outletId;
  const OutletSettingScreen({
    super.key,
    required this.storeId,
    required this.outletId,
  });

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
          color: Theme.of(context).primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withOpacity(0.5),
      indent: 56,
      endIndent: 16,
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyMedium?.color,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Column(children: children),
        ),
      ),
    );
  }

  Future<File?> _loadLocalProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_pic_local.png';
      final file = File(imagePath);
      if (await file.exists()) return file;
    } catch (e) {
      debugPrint("Gagal memuat gambar di settings: $e");
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Outlet Setting",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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

              // ── SECTION: Akun & Keamanan ────────────────────────────────
              _buildSectionLabel(context, "Akun & Keamanan"),
              const SizedBox(height: 12),
              _buildMenuCard(context, [
                _buildGroupedMenuItem(
                  context: context,
                  icon: Icons.print_disabled_outlined,
                  title: "Printer Setting",
                  subtitle: "Ubah Footer & Header Printer",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrinterSettingPage(
                        storeId: storeId,
                        outletId: outletId,
                      ),
                    ),
                  ).then((_) => (context as Element).markNeedsBuild()),
                ),

                _buildDivider(context),

                FutureBuilder<bool>(
                  future: canAccess('can_access_rak'),
                  builder: (context, snapshot) {
                    if (!(snapshot.data ?? false))
                      return const SizedBox.shrink();
                    return Column(
                      children: [
                        _buildGroupedMenuItem(
                          context: context,
                          icon: Icons.shelves,
                          title: "Rak Monitoring",
                          subtitle: "Pantau rak penyimpanan barang",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RakMonitoringScreen(
                                storeId: storeId,
                                outletId: outletId,
                              ),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                      ],
                    );
                  },
                ),

                FutureBuilder<bool>(
                  future: canAccess('can_access_layanan'),
                  builder: (context, snapshot) {
                    if (!(snapshot.data ?? false))
                      return const SizedBox.shrink();
                    return Column(
                      children: [
                        _buildGroupedMenuItem(
                          context: context,
                          icon: Icons.local_laundry_service_outlined,
                          title: "Daftar Layanan",
                          subtitle: "Ubah Layanan Laundry",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LayananScreen(
                                storeId: storeId,
                                outletId: outletId,
                              ),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                      ],
                    );
                  },
                ),

                _buildGroupedMenuItem(
                  context: context,
                  icon: Icons.phone_android_outlined,
                  title: "Daftar Pelanggan",
                  subtitle: "Ubah & tambah kontak pelanggan",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DaftarPelangganPage(
                        storeId: storeId,
                        outletId: outletId,
                      ),
                    ),
                  ),
                ),

                _buildDivider(context),

                FutureBuilder<bool>(
                  future: canAccess('can_access_outlet'),
                  builder: (context, snapshot) {
                    if (!(snapshot.data ?? false))
                      return const SizedBox.shrink();
                    return Column(
                      children: [
                        _buildGroupedMenuItem(
                          context: context,
                          icon: Icons.store_outlined,
                          title: "Kelola Outlet",
                          subtitle: "Nama, Alamat, No. HP, dan Logo Outlet",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OutletPage(
                                storeId: storeId,
                                outletId: outletId,
                              ),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                      ],
                    );
                  },
                ),

                FutureBuilder<bool>(
                  future: canAccess('can_access_admin'),
                  builder: (context, snapshot) {
                    if (!(snapshot.data ?? false))
                      return const SizedBox.shrink();
                    return _buildGroupedMenuItem(
                      context: context,
                      icon: Icons.admin_panel_settings_outlined,
                      title: "Kelola Admin",
                      subtitle: "Izin & Kelola Akses admin",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ManageAdminAccessScreen(storeId: storeId),
                        ),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),

              FutureBuilder<bool>(
                future: canAccess('can_access_wa_setting'),
                builder: (context, snapshot) {
                  if (!(snapshot.data ?? false)) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel(context, "Notifikasi"),
                      const SizedBox(height: 12),
                      const WaAutoSection(),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
