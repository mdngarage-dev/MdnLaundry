import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mdnlaundry_project/features/settings/outlet/admin_activation.dart';
import 'package:mdnlaundry_project/features/subscription/subscription_dashboard.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class SettingScreen extends StatefulWidget {
  final String storeId;
  final String outletId;
  final bool isOwner;

  const SettingScreen({
    super.key,
    required this.storeId,
    required this.outletId,
    required this.isOwner,
  });

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
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

  Future<String?> _getKodeToko() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .get();
      return doc.data()?['kode_toko']?.toString();
    } catch (e) {
      debugPrint("Gagal mengambil kode_toko: $e");
      return null;
    }
  }

  Widget _buildKodeTokoCard(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getKodeToko(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.5),
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final kodeToko = snapshot.data ?? '-';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimary, const Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.vpn_key_rounded,
                    color: Colors.white.withOpacity(0.85),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Kode Undangan Admin",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Bagikan kode ini ke Admin agar bisa daftar dan terhubung ke toko Anda",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        kodeToko,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: kodeToko));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Kode toko disalin ke clipboard"),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
      OneSignal.User.removeTag("store_id");
      OneSignal.User.removeTag("role");
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
          "Settings",
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

              // ── Card Profil Utama ───────────────────────────────────────
              if (!_isOwner()) ...[
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
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
                                (FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.displayName ??
                                        'User')
                                    .split('|')[0]
                                    .trim(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
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
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  getUserRole(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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
              ],

              if (_isOwner()) ...[
                const SizedBox(height: 16),
                _buildKodeTokoCard(context),
              ],

              const SizedBox(height: 25),

              Text(
                "Akun & Keamanan",
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // ── Grup Menu ───────────────────────────────────────────────
              Container(
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
                    // ← TAMBAH
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        // ── Akun & Keamanan ────────────────────────────────
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
                            ).then((_) => setState(() {}));
                          },
                        ),

                        // ── Outlet Setting ─
                        _buildDivider(context),
                        _buildGroupedMenuItem(
                          context: context,
                          icon: Icons.store_outlined,
                          title: "Outlet Setting",
                          subtitle: "Printer, Layanan, Informasi Outlet",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OutletSettingScreen(
                                storeId: widget.storeId,
                                outletId: widget.outletId,
                              ),
                            ),
                          ),
                        ),

                        if (widget.isOwner) ...[
                          _buildDivider(context),
                          FutureBuilder<bool>(
                            future: _isAppOwner(),
                            builder: (context, snapshot) {
                              // Jika Developer (is_app_owner = true), hide menu ini
                              if (snapshot.hasData && snapshot.data == true) {
                                return const SizedBox.shrink();
                              }

                              return _buildGroupedMenuItem(
                                context: context,
                                icon: Icons.subscriptions_rounded,
                                title: "Subscription Management",
                                subtitle: "Kelola paket dan revenue",
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SubscriptionDashboard(
                                      storeId: widget.storeId,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        // ── Kelola Admin (hanya tampil jika Owner) ── TAMBAH INI
                        if (widget.isOwner) ...[
                          _buildDivider(context),
                          _buildGroupedMenuItem(
                            context: context,
                            icon: Icons.how_to_reg_outlined,
                            title: "Aktivasi & Akses Admin",
                            subtitle:
                                "Setujui pendaftaran dan atur izin admin per outlet",
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminActivationScreen(
                                  storeId: widget.storeId,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // ── Mode Warna ─────────────────────────────────────
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
                              backgroundColor: Theme.of(context).cardColor,
                              builder: (context) {
                                final themeProvider =
                                    Provider.of<ThemeProvider>(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                                      const Divider(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          "Warna Tema",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Wrap(
                                          spacing: 16,
                                          runSpacing: 12,
                                          children: List.generate(
                                            kThemeColorPresets.length,
                                            (index) {
                                              final preset =
                                                  kThemeColorPresets[index];
                                              return _ColorBadge(
                                                color: preset.light,
                                                label: preset.label,
                                                isSelected:
                                                    themeProvider
                                                        .seedColorIndex ==
                                                    index,
                                                onTap: () {
                                                  themeProvider.changeColor(
                                                    index,
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        // ── Tentang Aplikasi ───────────────────────────────
                        _buildDivider(context),
                        _buildGroupedMenuItem(
                          context: context,
                          icon: Icons.info_outline,
                          title: "Tentang Aplikasi",
                          subtitle:
                              "Versi ${AppConfig.appVersion} - Laundry Ku",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TentangAplikasiPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Tombol Sign Out ─────────────────────────────────────────
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
            "Apakah Anda yakin ingin keluar dari ${OutletSettings.namaLaundry}?",
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

  bool _isOwner() {
    final displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';
    final parts = displayName.split('|');
    if (parts.length < 3) return false;
    return parts[2].trim() == 'Owner';
  }

  Future<bool> _isAppOwner() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      return doc.data()?['is_app_owner'] ?? false;
    } catch (e) {
      return false;
    }
  }
}

class _ColorBadge extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ColorBadge({
    required this.color,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.black87, width: 2.5)
                  : Border.all(color: Colors.black12, width: 1),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
