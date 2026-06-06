import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/screens/screens.dart';

class DaftarPelangganPage extends StatefulWidget {
  final bool isSelecting;

  const DaftarPelangganPage({super.key, this.isSelecting = false});

  @override
  State<DaftarPelangganPage> createState() => _DaftarPelangganPageState();
}

class _DaftarPelangganPageState extends State<DaftarPelangganPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _namaCtrl = TextEditingController();
  final TextEditingController _noHpCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  // Semua data pelanggan disimpan di sini (dari Firestore stream)
  List<QueryDocumentSnapshot> _allDocs = [];
  // Data yang tampil setelah difilter
  List<QueryDocumentSnapshot> _filteredDocs = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _noHpCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Filter di memory — tanpa query ke Firestore, jadi instant
  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDocs = List.from(_allDocs);
      } else {
        _filteredDocs = _allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nama = (data['nama'] ?? '').toString().toLowerCase();
          final noHp = (data['no_hp'] ?? '').toString().toLowerCase();
          return nama.contains(query) || noHp.contains(query);
        }).toList();
      }
    });
  }

  // Update _allDocs setiap stream emit data baru, lalu re-apply filter
  void _updateDocs(List<QueryDocumentSnapshot> docs) {
    _allDocs = docs;
    _onSearchChanged(); // langsung apply filter yang sedang aktif
  }

  // Ambil 1–2 inisial dari nama untuk avatar
  String _getInitials(String nama) {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  // Warna avatar unik berdasarkan nama (deterministik)
  Color _getAvatarColor(String nama) {
    const colors = [
      Color(0xFF1976D2),
      Color(0xFF388E3C),
      Color(0xFFF57C00),
      Color(0xFF7B1FA2),
      Color(0xFFC62828),
      Color(0xFF00838F),
      Color(0xFF5D4037),
      Color(0xFF455A64),
    ];
    final index = nama.isEmpty ? 0 : nama.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  // ── Dialog Tambah / Edit Pelanggan ──
  void _showFormDialog({
    String? docId,
    String? currentNama,
    String? currentNoHp,
  }) {
    _namaCtrl.text = currentNama ?? '';
    _noHpCtrl.text = currentNoHp ?? '';
    final bool isEdit = docId != null;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(isEdit ? 'Edit Pelanggan' : 'Tambah Pelanggan Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _namaCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Pelanggan',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noHpCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nama = _namaCtrl.text.trim();
                final noHp = _noHpCtrl.text.trim();
                if (nama.isEmpty || noHp.isEmpty) return;

                if (isEdit) {
                  await _firestore.collection('pelanggan').doc(docId).update({
                    'nama': nama,
                    'no_hp': noHp,
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                } else {
                  await _firestore.collection('pelanggan').add({
                    'nama': nama,
                    'no_hp': noHp,
                    'created_at': FieldValue.serverTimestamp(),
                  });
                }

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Pelanggan berhasil ${isEdit ? "diubah" : "disimpan"}',
                      ),
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Simpan' : 'Tambah'),
            ),
          ],
        );
      },
    );
  }

  // ── Dialog Edit Nomor HP saja (dari subtitle / tombol khusus) ──
  void _showEditNoHpDialog(String docId, String currentNoHp) {
    _noHpCtrl.text = currentNoHp;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Nomor HP'),
        content: TextField(
          controller: _noHpCtrl,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nomor HP',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final noHp = _noHpCtrl.text.trim();
              if (noHp.isEmpty) return;
              await _firestore.collection('pelanggan').doc(docId).update({
                'no_hp': noHp,
                'updated_at': FieldValue.serverTimestamp(),
              });
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nomor HP berhasil diubah')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── Konfirmasi Hapus ──
  void _konfirmasiHapus(String docId, String nama) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pelanggan'),
        content: Text('Apakah Anda yakin ingin menghapus $nama dari daftar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await _firestore.collection('pelanggan').doc(docId).delete();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$nama dihapus')));
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('pelanggan').orderBy('nama').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Terjadi kesalahan saat memuat data'),
            );
          }

          // Update data lokal setiap ada data baru dari Firestore
          // Loading hanya muncul saat pertama kali (belum ada data sama sekali)
          if (snapshot.hasData) {
            final incoming = snapshot.data!.docs;
            // Cek apakah data berubah sebelum update agar tidak trigger rebuild ganda
            if (_allDocs.length != incoming.length ||
                (incoming.isNotEmpty &&
                    (_allDocs.isEmpty ||
                        _allDocs.first.id != incoming.first.id))) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateDocs(incoming);
              });
            }
          }

          // Tampilkan loading hanya saat benar-benar belum ada data lokal
          if (snapshot.connectionState == ConnectionState.waiting &&
              _allDocs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_allDocs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada data pelanggan.\nSilakan tambah terlebih dahulu.',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (_filteredDocs.isEmpty && _searchCtrl.text.isNotEmpty) {
            return Column(
              children: [
                _buildSearchBar(),
                const Expanded(
                  child: Center(child: Text('Pelanggan tidak ditemukan')),
                ),
              ],
            );
          }

          return Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredDocs.length,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemBuilder: (context, index) {
                    final doc = _filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String nama = data['nama'] ?? '-';
                    final String noHp = data['no_hp'] ?? '-';
                    final String initials = _getInitials(nama);
                    final Color avatarColor = _getAvatarColor(nama);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // Shadow sedikit
                      elevation: 3,
                      shadowColor: Colors.black26,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: avatarColor,
                          radius: 22,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        title: Text(
                          nama,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(noHp),
                        // Tombol edit & hapus selalu tampil,
                        // termasuk saat isSelecting — tap card tetap untuk memilih
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.orange,
                              ),
                              onPressed: () => _showFormDialog(
                                docId: doc.id,
                                currentNama: nama,
                                currentNoHp: noHp,
                              ),
                            ),
                            FutureBuilder<bool>(
                              future: canAccess('can_hapus_pelanggan'),
                              builder: (context, snapshot) {
                                if (!(snapshot.data ?? false)) {
                                  return const SizedBox.shrink();
                                }
                                return IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _konfirmasiHapus(doc.id, nama),
                                );
                              },
                            ),
                            if (widget.isSelecting)
                              const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          if (widget.isSelecting) {
                            Navigator.pop(context, {
                              'nama': nama,
                              'no_hp': noHp,
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Search Bar ──
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Cari nama atau nomor HP...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    // _onSearchChanged otomatis dipanggil via listener
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── AppBar ──
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
            widget.isSelecting ? 'Pilih Pelanggan' : 'Daftar No HP Pelanggan',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
      ),
    );
  }
}
