import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ManageAdminAccessScreen — List semua Admin
// ─────────────────────────────────────────────────────────────────────────────
class ManageAdminAccessScreen extends StatelessWidget {
  const ManageAdminAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Kelola Admin",
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Admin')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "Belum ada Admin terdaftar",
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            );
          }

          final admins = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: admins.length,
            itemBuilder: (context, index) {
              final admin = admins[index];
              final data = admin.data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    child: Text(
                      (data['nama'] ?? 'A')[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    data['nama'] ?? 'Admin',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  subtitle: Text(
                    data['nip'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).hintColor,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditAdminPermissionScreen(
                          adminUid: admin.id,
                          adminName: data['nama'] ?? 'Admin',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EditAdminPermissionScreen — Edit izin per-Admin
// ─────────────────────────────────────────────────────────────────────────────

// Model izin — untuk nambah izin baru cukup tambah item di sini
class _Permission {
  final String key; // key di Firestore
  final String label; // teks yang tampil
  final String subtitle; // keterangan
  final IconData icon;
  final bool ownerOnly;

  const _Permission({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.ownerOnly = false,
  });
}

// ── Daftar izin — TAMBAH IZIN BARU DI SINI ───────────────────────────────────
const List<_Permission> _allPermissions = [
  _Permission(
    key: 'can_access_ringkasan',
    label: 'Ringkasan Outlet',
    subtitle: 'Analisis performa bisnis lengkap',
    icon: Icons.grid_view_rounded,
  ),
  _Permission(
    key: 'can_access_harian',
    label: 'Laporan Harian',
    subtitle: 'Ringkasan transaksi hari ini',
    icon: Icons.calendar_today_rounded,
  ),
  _Permission(
    key: 'can_access_lispengeluaran',
    label: 'Pengeluaran',
    subtitle: 'Laporan detail pengeluaran',
    icon: Icons.shopping_bag_outlined,
  ),
  _Permission(
    key: 'can_access_layanan',
    label: 'Daftar Layanan',
    subtitle: 'Ubah Layanan Laundry',
    icon: Icons.local_laundry_service_outlined,
  ),
  _Permission(
    key: 'can_access_outlet',
    label: 'Kelola Outlet',
    subtitle: 'Nama, Alamat, No. HP, dan Logo Outlet',
    icon: Icons.store_outlined,
  ),
  _Permission(
    key: 'can_access_admin',
    label: 'Kelola Admin',
    subtitle: 'Izin & Kelola Akses admin',
    icon: Icons.admin_panel_settings_outlined,
  ),
  _Permission(
    key: 'can_hapus_order',
    label: 'Hapus Order',
    subtitle: 'Izin menghapus order',
    icon: Icons.delete_outline_rounded,
  ),
  _Permission(
    key: 'can_hapus_pelanggan',
    label: 'Hapus No Pelanggan',
    subtitle: 'Izin menghapus Nomor',
    icon: Icons.delete_outline_rounded,
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Label section ──────────────────────────────────────
                Text(
                  "IZIN AKSES",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Card izin ──────────────────────────────────────────
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
                      children: _allPermissions.map((p) {
                        final isLast = p == _allPermissions.last;
                        return Column(
                          children: [
                            CheckboxListTile(
                              value: _permissions[p.key] ?? false,
                              onChanged: (val) {
                                setState(() {
                                  _permissions[p.key] = val ?? false;
                                });
                              },
                              title: Text(
                                p.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
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
                                color: Theme.of(
                                  context,
                                ).dividerColor.withOpacity(0.5),
                                indent: 56,
                                endIndent: 16,
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
