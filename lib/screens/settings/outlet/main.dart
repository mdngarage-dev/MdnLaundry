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
        child: Column(children: children),
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
                      builder: (_) => const PrinterSettingPage(),
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
                              builder: (_) => const RakMonitoringScreen(),
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
                              builder: (_) => const LayananScreen(),
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
                      builder: (_) => const DaftarPelangganPage(),
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
                              builder: (_) => const OutletPage(),
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
                          builder: (_) => const ManageAdminAccessScreen(),
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
                      const _WaAutoSection(),
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

// ══════════════════════════════════════════════════════════════════════════════
//  WA AUTO SECTION WIDGET
// ══════════════════════════════════════════════════════════════════════════════
class _WaAutoSection extends StatefulWidget {
  const _WaAutoSection();

  @override
  State<_WaAutoSection> createState() => _WaAutoSectionState();
}

class _WaAutoSectionState extends State<_WaAutoSection> {
  bool _enabled = false;
  bool _loading = true;
  bool _tokenVisible = false;
  bool _saving = false;
  final _tokenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final enabled = await WaSettings.isEnabled();
    final token = await WaSettings.getToken();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _loading = false;
        _tokenCtrl.text = token;
      });
    }
  }

  Future<void> _saveToken() async {
    if (_tokenCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await WaSettings.setToken(_tokenCtrl.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Token Fonnte berhasil disimpan'),
            ],
          ),
          backgroundColor: const Color(0xFF25D366),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showPreviewPesan() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.send, color: Color(0xFF25D366), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Contoh Pesan WA',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pesan yang dikirim otomatis ke pelanggan',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            // Bubble chat WA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF8C6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Halo, *Ibu Tia* 👋\n\n'
                'Terima kasih telah mempercayakan laundry Anda! '
                'Pesanan telah kami terima.\n\n'
                '📋 *Detail Order:*\n'
                '• No. Order       : *MDN260611028*\n'
                '• Layanan          : Setrika Reguler\n'
                '• Total               : *Rp 46.000*\n'
                '• Pembayaran   : ⏳ Bayar saat ambil\n'
                '• Est. Selesai     : 14-06-2026\n\n'
                '🔍 *Lacak status order Anda:*\n'
                'https://laundry-ku-id.web.app/MDN260611028\n\n'
                'Kami segera memproses laundry Anda. Terima kasih! 🙏\n\n'
                '_Madeena Laundry_',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Dikirim otomatis saat order disimpan',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const waGreen = Color(0xFF25D366);

    if (_loading) {
      return Container(
        height: 72,
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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _enabled
              ? waGreen.withOpacity(0.4)
              : Theme.of(context).dividerColor.withOpacity(0.5),
          width: _enabled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _enabled
                ? waGreen.withOpacity(0.08)
                : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row (selalu tampil) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Icon WA
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: waGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send, color: waGreen, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Title & subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp Otomatis',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _enabled
                              ? 'Aktif – pesan dikirim via Fonnte'
                              : 'Nonaktif – buka WA manual',
                          style: TextStyle(
                            fontSize: 12,
                            color: _enabled
                                ? waGreen
                                : Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: _enabled
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Toggle switch
                  Switch.adaptive(
                    value: _enabled,
                    activeColor: waGreen,
                    onChanged: (val) async {
                      await WaSettings.setEnabled(val);
                      setState(() => _enabled = val);
                    },
                  ),
                ],
              ),
            ),

            // ── Expanded content (hanya jika ON) ───────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _enabled
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: waGreen.withOpacity(0.2),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info banner Fonnte
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: waGreen.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: waGreen.withOpacity(0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: waGreen,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                            height: 1.5,
                                          ),
                                          children: const [
                                            TextSpan(
                                              text:
                                                  'Daftarkan nomor WA kamu di ',
                                            ),
                                            TextSpan(
                                              text: 'fonnte.com',
                                              style: TextStyle(
                                                color: waGreen,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  ' lalu salin token dari Dashboard → Token API.',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Label token
                              Text(
                                'Token Fonnte',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Input token
                              TextField(
                                controller: _tokenCtrl,
                                obscureText: !_tokenVisible,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                  letterSpacing: _tokenVisible ? 0.5 : 2,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Paste token Fonnte di sini...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                    letterSpacing: 0,
                                    fontFamily: 'sans-serif',
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _tokenVisible
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 18,
                                      color: Colors.grey.shade400,
                                    ),
                                    onPressed: () => setState(
                                      () => _tokenVisible = !_tokenVisible,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: waGreen,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Tombol simpan token
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _saving || _tokenCtrl.text.trim().isEmpty
                                      ? null
                                      : _saveToken,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save_outlined,
                                          size: 16,
                                        ),
                                  label: Text(
                                    _saving ? 'Menyimpan...' : 'Simpan Token',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: waGreen,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Divider tipis sebelum preview ─────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Divider(
                            height: 1,
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.4),
                          ),
                        ),

                        // ── Tombol preview pesan (seperti ListTile) ───────
                        InkWell(
                          onTap: _showPreviewPesan,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.preview_outlined,
                                    color: Theme.of(context).primaryColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lihat Contoh Pesan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      Text(
                                        'Preview pesan WA ke pelanggan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Theme.of(context).hintColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
