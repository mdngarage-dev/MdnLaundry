import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ─────────────────────────────────────────────────────────────────────────────
// EditAdminPermissionScreen — Edit izin per-Admin
// ─────────────────────────────────────────────────────────────────────────────

// Model izin — untuk nambah izin baru cukup tambah item di sini
// Tambah field group di _Permission
class _Permission {
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final String group; // ← TAMBAH INI

  const _Permission({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.group, // ← TAMBAH INI
  });
}

const List<_Permission> _allPermissions = [
  // ── Laporan ────────────────────────────────────────────────────────────
  _Permission(
    key: 'can_access_ringkasan',
    label: 'Ringkasan Outlet',
    subtitle: 'Analisis performa bisnis lengkap',
    icon: Icons.grid_view_rounded,
    group: 'Laporan',
  ),
  _Permission(
    key: 'can_access_harian',
    label: 'Laporan Harian',
    subtitle: 'Ringkasan transaksi hari ini',
    icon: Icons.calendar_today_rounded,
    group: 'Laporan',
  ),
  _Permission(
    key: 'can_access_lispengeluaran',
    label: 'Pengeluaran',
    subtitle: 'Laporan detail pengeluaran',
    icon: Icons.shopping_bag_outlined,
    group: 'Laporan',
  ),

  // ── Order ──────────────────────────────────────────────────────────────
  _Permission(
    key: 'can_eit_layanan',
    label: 'Edit Pesanan',
    subtitle: 'Di halaman detail order',
    icon: Icons.edit_outlined,
    group: 'Order',
  ),
  _Permission(
    key: 'can_hapus_order',
    label: 'Hapus Order',
    subtitle: 'Izin menghapus order',
    icon: Icons.delete_outline_rounded,
    group: 'Order',
  ),
  _Permission(
    key: 'can_hapus_pelanggan',
    label: 'Hapus No Pelanggan',
    subtitle: 'Izin menghapus nomor pelanggan',
    icon: Icons.person_remove_outlined,
    group: 'Order',
  ),

  // ── Pengaturan Outlet ──────────────────────────────────────────────────
  _Permission(
    key: 'can_access_layanan',
    label: 'Daftar Layanan',
    subtitle: 'Ubah layanan laundry',
    icon: Icons.local_laundry_service_outlined,
    group: 'Pengaturan Outlet',
  ),
  _Permission(
    key: 'can_access_rak',
    label: 'Rak Monitoring',
    subtitle: 'Pantau rak penyimpanan barang',
    icon: Icons.shelves,
    group: 'Pengaturan Outlet',
  ),
  _Permission(
    key: 'can_access_outlet',
    label: 'Kelola Outlet',
    subtitle: 'Nama, Alamat, No. HP, dan Logo Outlet',
    icon: Icons.store_outlined,
    group: 'Pengaturan Outlet',
  ),
  _Permission(
    key: 'can_access_togle_nohp',
    label: 'Tampilkan No HP Outlet',
    subtitle: 'Nomor HP outlet muncul di struk',
    icon: Icons.phone_outlined,
    group: 'Pengaturan Outlet',
  ),
  _Permission(
    key: 'can_access_togle_alamat',
    label: 'Tampilkan Alamat Outlet',
    subtitle: 'Alamat outlet muncul di struk',
    icon: Icons.location_on_outlined,
    group: 'Pengaturan Outlet',
  ),

  _Permission(
    key: 'can_access_nota',
    label: 'Tampilkan Kolom Custom Nota',
    subtitle: 'Custom Nota di struk',
    icon: Icons.book_online_outlined,
    group: 'Pengaturan Outlet',
  ),

  // ── Keuangan ───────────────────────────────────────────────────────────
  _Permission(
    key: 'can_kelola_rekening',
    label: 'Kelola Rekening',
    subtitle: 'Tambah, Hapus, Edit Rekening di Struk',
    icon: Icons.atm_outlined,
    group: 'Keuangan',
  ),

  // ── Sistem ─────────────────────────────────────────────────────────────
  _Permission(
    key: 'can_access_wa_setting',
    label: 'Pengaturan WA Otomatis',
    subtitle: 'Kelola token Fonnte & notifikasi WA',
    icon: Icons.send,
    group: 'Sistem',
  ),
  _Permission(
    key: 'can_access_admin',
    label: 'Kelola Admin',
    subtitle: 'Izin & Kelola Akses Admin',
    icon: Icons.admin_panel_settings_outlined,
    group: 'Sistem',
  ),
];

class EditAdminPermissionScreen extends StatefulWidget {
  final String adminUid;
  final String adminName;

  const EditAdminPermissionScreen({
    super.key,
    required this.adminUid,
    required this.adminName,
  });

  @override
  State<EditAdminPermissionScreen> createState() =>
      _EditAdminPermissionScreenState();
}

class _EditAdminPermissionScreenState extends State<EditAdminPermissionScreen> {
  // Map izin sementara sebelum disimpan
  final Map<String, bool> _permissions = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _konfirmasiHapusAdmin() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Akun Admin?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: "Akun "),
                  TextSpan(
                    text: widget.adminName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        " akan dihapus permanen.\n\nData order dan transaksi yang pernah dibuat tidak ikut terhapus.",
                  ),
                ],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Ya, Hapus",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi == true) await _hapusAkunAdmin();
  }

  Future<void> _hapusAkunAdmin() async {
    setState(() => _isSaving = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("Tidak ada user login");

      // Trigger GitHub Actions workflow_dispatch
      final response = await http.post(
        Uri.parse(
          "https://api.github.com/repos/mdngarage-dev/MdnLaundry/actions/workflows/delete-admin.yml/dispatches",
        ),
        headers: {
          "Authorization":
              "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",
          "Accept": "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
        },
        body: jsonEncode({
          "ref": "main", // branch utama kamu
          "inputs": {
            "caller_uid": currentUser.uid,
            "target_uid": widget.adminUid,
          },
        }),
      );

      // GitHub kembalikan 204 jika berhasil trigger
      if (response.statusCode == 204) {
        // Hapus dokumen Firestore langsung dari Flutter
        // (GitHub Actions butuh ~30 detik, Firestore bisa langsung)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.adminUid)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Akun ${widget.adminName} berhasil dihapus permanen",
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(
          "GitHub API error: ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus akun: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminUid)
          .get();

      final data = doc.data() ?? {};
      setState(() {
        for (final p in _allPermissions) {
          _permissions[p.key] = data[p.key] ?? false;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Gagal load izin: $e");
    }
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminUid)
          .update(_permissions.map((k, v) => MapEntry(k, v)));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Izin berhasil disimpan"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal simpan: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.adminName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePermissions,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Simpan",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    100,
                  ), // ← tambah bottom padding
                  children: _buildGroupedSections(context),
                ),

                // ── Tombol Hapus di bawah ──────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.4),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _konfirmasiHapusAdmin,
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Hapus Akun Admin Ini",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildGroupedSections(BuildContext context) {
    // Ambil urutan group tanpa duplikat
    final groups = <String>[];
    for (final p in _allPermissions) {
      if (!groups.contains(p.group)) groups.add(p.group);
    }

    final widgets = <Widget>[];

    for (final group in groups) {
      final items = _allPermissions.where((p) => p.group == group).toList();

      // ── Label section ──────────────────────────────────────────────────
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8, left: 2),
          child: Text(
            group.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );

      // ── Card per group ─────────────────────────────────────────────────
      widgets.add(
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final isLast = idx == items.length - 1;
                return Column(
                  children: [
                    CheckboxListTile(
                      value: _permissions[p.key] ?? false,
                      onChanged: (val) =>
                          setState(() => _permissions[p.key] = val ?? false),
                      title: Text(
                        p.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        p.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          p.icon,
                          color: Theme.of(context).primaryColor,
                          size: 22,
                        ),
                      ),
                      activeColor: Theme.of(context).primaryColor,
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                        indent: 56,
                        endIndent: 16,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      );

      widgets.add(const SizedBox(height: 4));
    }

    return widgets;
  }
}
