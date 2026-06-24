import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mdnlaundry_project/screens/settings/outlet/izin_admin.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';

class AdminActivationScreen extends StatefulWidget {
  final String storeId;
  const AdminActivationScreen({super.key, required this.storeId});

  @override
  State<AdminActivationScreen> createState() => _AdminActivationScreenState();
}

class _AdminActivationScreenState extends State<AdminActivationScreen> {
  @override
  Widget build(BuildContext context) {
    final appBarColor =
        Theme.of(context).appBarTheme.backgroundColor ?? kPrimary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: false,
        // ── AppBar + TabBar disatukan dalam 1 blok visual ──────────
        // (tidak pakai 'shape' rounded di AppBar lagi, supaya tidak ada
        // 2 lengkungan terpisah yang kelihatan seperti 2 appbar)
        appBar: AppBar(
          title: const Text(
            'Aktivasi & Akses Admin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          // shape DIHAPUS dari sini — dipindah jadi 1 bentuk besar
          // yang membungkus AppBar + TabBar via 'flexibleSpace'/Container
          // di bawah, supaya hanya ada SATU lengkungan di bagian bawah.
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          bottom: PreferredSize(
            // height tetap & eksplisit -> icon+text tab tidak akan
            // pernah ke-collapse / hilang saat ganti tab
            preferredSize: const Size.fromHeight(56),
            child: Container(
              decoration: const BoxDecoration(
                // TIDAK pakai color/boxShadow/borderRadius lagi di sini.
                // Background sudah disediakan oleh AppBar (warna sama),
                // jadi tidak ada 'kotak kedua' yang menimpa/menutupi
                // area icon Tab.
                color: Colors.transparent,
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                // labelPadding diberi supaya icon+text selalu punya
                // ruang yang cukup, tidak ketekan/overflow saat
                // transisi animasi pindah tab
                labelPadding: const EdgeInsets.symmetric(vertical: 6),
                tabs: const [
                  Tab(
                    height: 48,
                    icon: Icon(Icons.hourglass_empty_rounded, size: 20),
                    text: 'Menunggu',
                  ),
                  Tab(
                    height: 48,
                    icon: Icon(Icons.check_circle_outline_rounded, size: 20),
                    text: 'Aktif',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _AdminWaitingTab(storeId: widget.storeId),
            _AdminActiveTab(storeId: widget.storeId),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Admin Menunggu ──────────────────────────────────────────────────
class _AdminWaitingTab extends StatelessWidget {
  final String storeId;
  const _AdminWaitingTab({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('store_id', isEqualTo: storeId)
          .where('role', isEqualTo: 'Admin')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            title: 'Tidak ada pendaftaran baru',
            subtitle: 'Semua admin sudah diaktifkan',
          );
        }

        final admins = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Tampilkan jika is_activated = false ATAU field tidak ada
          return (data['is_activated'] ?? false) == false;
        }).toList();

        if (admins.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            title: 'Tidak ada pendaftaran baru',
            subtitle: 'Semua admin sudah diaktifkan',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: admins.length,
          itemBuilder: (context, idx) {
            final admin = admins[idx];
            final adminUid = admin.id;
            final data = admin.data() as Map<String, dynamic>;
            final nama = data['nama'] ?? 'Admin';
            final email = data['email'] ?? '';
            final nip = data['nip'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: Colors.orange,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nama,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                              if (nip.isNotEmpty)
                                Text(
                                  'NIP: $nip',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Menunggu',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: Colors.grey.withOpacity(0.12)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showRejectDialog(context, adminUid, nama),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Tolak',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showActivateDialog(
                              context,
                              storeId,
                              adminUid,
                              nama,
                            ),
                            icon: const Icon(
                              Icons.how_to_reg_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Aktivasi',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, String adminUid, String nama) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tolak Pendaftaran?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.5),
            children: [
              const TextSpan(text: 'Akun '),
              TextSpan(
                text: nama,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' akan dihapus.\nAdmin bisa mendaftar ulang nanti.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(color: Theme.of(ctx).primaryColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _rejectAdmin(context, adminUid);
            },
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectAdmin(BuildContext context, String adminUid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Pendaftaran admin ditolak'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal tolak admin: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showActivateDialog(
    BuildContext context,
    String storeId,
    String adminUid,
    String nama,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _ActivateAdminDialog(
        storeId: storeId,
        adminUid: adminUid,
        adminName: nama,
      ),
    );
  }
}

// ── Tab 2: Admin Aktif ─────────────────────────────────────────────────────
class _AdminActiveTab extends StatelessWidget {
  final String storeId;
  const _AdminActiveTab({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('store_id', isEqualTo: storeId)
          .where('role', isEqualTo: 'Admin')
          .where('is_activated', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.person_outline_rounded,
            color: Colors.grey,
            title: 'Belum ada admin aktif',
            subtitle: 'Admin yang diaktivasi akan muncul di sini',
          );
        }

        final admins = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['is_activated'] ?? false) == true;
        }).toList();

        if (admins.isEmpty) {
          return _buildEmptyState(
            icon: Icons.person_outline_rounded,
            color: Colors.grey,
            title: 'Belum ada admin aktif',
            subtitle: 'Admin yang diaktivasi akan muncul di sini',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: admins.length,
          itemBuilder: (context, idx) {
            final admin = admins[idx];
            final adminUid = admin.id;
            final data = admin.data() as Map<String, dynamic>;
            final nama = data['nama'] ?? 'Admin';
            final email = data['email'] ?? '';
            final allowedOutlets = List<String>.from(
              data['allowed_outlets'] ?? [],
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${allowedOutlets.length} outlet aktif',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: kPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: Colors.grey.shade400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          onTap: () => Future.microtask(
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditAdminPermissionScreen(
                                  adminUid: adminUid,
                                  adminName: nama,
                                  storeId: storeId,
                                ),
                              ),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Edit Izin'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          onTap: () => Future.microtask(
                            () => _showPindahOutletDialog(
                              context,
                              storeId,
                              adminUid,
                              nama,
                              allowedOutlets,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.store_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Pindah Outlet'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPindahOutletDialog(
    BuildContext context,
    String storeId,
    String adminUid,
    String adminName,
    List<String> currentOutlets,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _PindahOutletDialog(
        storeId: storeId,
        adminUid: adminUid,
        adminName: adminName,
        currentOutlets: currentOutlets,
      ),
    );
  }
}

// ── Empty State Helper ─────────────────────────────────────────────────────
Widget _buildEmptyState({
  required IconData icon,
  required Color color,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 40, color: color.withOpacity(0.5)),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    ),
  );
}

// ── Dialog Aktivasi (tidak berubah) ────────────────────────────────────────
class _ActivateAdminDialog extends StatefulWidget {
  final String storeId;
  final String adminUid;
  final String adminName;

  const _ActivateAdminDialog({
    required this.storeId,
    required this.adminUid,
    required this.adminName,
  });

  @override
  State<_ActivateAdminDialog> createState() => _ActivateAdminDialogState();
}

class _ActivateAdminDialogState extends State<_ActivateAdminDialog> {
  List<String> _selectedOutlets = [];
  final Map<String, Map<String, bool>> _permissions = {};
  bool _isLoading = false;

  Map<String, bool> _defaultPermissions() => {
    'can_access_ringkasan': true,
    'can_access_harian': true,
    'can_access_lispengeluaran': true,
    'can_eit_layanan': true,
    'can_hapus_order': false,
    'can_hapus_pelanggan': false,
    'can_access_layanan': false,
    'can_access_rak': false,
    'can_access_outlet': false,
    'can_access_togle_nohp': false,
    'can_access_togle_alamat': false,
    'can_access_nota': false,
    'can_kelola_rekening': false,
    'can_access_wa_setting': false,
    'can_access_admin': false,
  };

  Future<void> _aktivasiAdmin() async {
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminUid);
      batch.update(userRef, {
        'is_activated': true,
        'allowed_outlets': _selectedOutlets,
        'current_outlet_id': _selectedOutlets.first,
      });
      for (var outletId in _selectedOutlets) {
        final permRef = FirebaseFirestore.instance
            .collection('store_permissions')
            .doc(widget.storeId)
            .collection(outletId)
            .doc(widget.adminUid);
        batch.set(permRef, _permissions[outletId] ?? {});
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Admin berhasil diaktifkan!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal aktivasi: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPermissionCheckbox(String label, String permissionKey) {
    return CheckboxListTile(
      value: _permissions.values.fold<bool>(
        false,
        (prev, perms) => prev || (perms[permissionKey] ?? false),
      ),
      onChanged: (val) {
        setState(() {
          for (var outletId in _selectedOutlets) {
            _permissions[outletId]?[permissionKey] = val ?? false;
          }
        });
      },
      title: Text(label, style: const TextStyle(fontSize: 13)),
      dense: true,
      contentPadding: EdgeInsets.zero,
      activeColor: kPrimary,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary, const Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktivasi Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.adminName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pilih Outlet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('stores')
                        .doc(widget.storeId)
                        .collection('outlets')
                        .orderBy('is_utama', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      return Column(
                        children: snapshot.data!.docs.map((outlet) {
                          final outletId = outlet.id;
                          final outletName = outlet['nama_outlet'] ?? 'Outlet';
                          final isSelected = _selectedOutlets.contains(
                            outletId,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: kPrimary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedOutlets.add(outletId);
                                  _permissions[outletId] =
                                      _defaultPermissions();
                                } else {
                                  _selectedOutlets.remove(outletId);
                                  _permissions.remove(outletId);
                                }
                              });
                            },
                            title: Text(outletName),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      );
                    },
                  ),
                  if (_selectedOutlets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.withOpacity(0.15)),
                    const SizedBox(height: 8),
                    Text(
                      'Izin Default',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPermissionCheckbox(
                      'Akses Laporan',
                      'can_access_ringkasan',
                    ),
                    _buildPermissionCheckbox('Edit Pesanan', 'can_eit_layanan'),
                    _buildPermissionCheckbox(
                      'Kelola Rekening',
                      'can_kelola_rekening',
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedOutlets.isEmpty || _isLoading
                          ? null
                          : _aktivasiAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Aktivasi',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog Pindah Outlet ────────────────────────────────────────────────────
class _PindahOutletDialog extends StatefulWidget {
  final String storeId;
  final String adminUid;
  final String adminName;
  final List<String> currentOutlets;

  const _PindahOutletDialog({
    required this.storeId,
    required this.adminUid,
    required this.adminName,
    required this.currentOutlets,
  });

  @override
  State<_PindahOutletDialog> createState() => _PindahOutletDialogState();
}

class _PindahOutletDialogState extends State<_PindahOutletDialog> {
  late List<String> _selectedOutlets;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedOutlets = List.from(widget.currentOutlets);
  }

  Future<void> _simpan() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.adminUid)
          .update({
            'allowed_outlets': _selectedOutlets,
            'current_outlet_id': _selectedOutlets.first,
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Outlet admin berhasil diperbarui!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal update: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary, const Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pindah / Ubah Outlet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.adminName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('stores')
                    .doc(widget.storeId)
                    .collection('outlets')
                    .orderBy('is_utama', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: snapshot.data!.docs.map((outlet) {
                      final outletId = outlet.id;
                      final outletName = outlet['nama_outlet'] ?? 'Outlet';
                      final isSelected = _selectedOutlets.contains(outletId);
                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: kPrimary,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedOutlets.add(outletId);
                            } else {
                              _selectedOutlets.remove(outletId);
                            }
                          });
                        },
                        title: Text(outletName),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedOutlets.isEmpty || _isLoading
                          ? null
                          : _simpan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Simpan',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
