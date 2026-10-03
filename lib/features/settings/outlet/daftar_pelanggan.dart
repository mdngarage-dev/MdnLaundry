import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class DaftarPelangganPage extends StatefulWidget {
  final bool isSelecting;
  final String storeId;
  final String outletId;

  const DaftarPelangganPage({
    super.key,
    this.isSelecting = false,
    required this.storeId,
    required this.outletId,
  });
  @override
  State<DaftarPelangganPage> createState() => _DaftarPelangganPageState();
}

class _DaftarPelangganPageState extends State<DaftarPelangganPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _namaCtrl = TextEditingController();
  final TextEditingController _noHpCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<QueryDocumentSnapshot> _allDocs = [];
  List<QueryDocumentSnapshot> _filteredDocs = [];

  bool _isExporting = false;

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

  void _updateDocs(List<QueryDocumentSnapshot> docs) {
    _allDocs = docs;
    _onSearchChanged();
  }

  String _getInitials(String nama) {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

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

  // ── Export CSV ──────────────────────────────────────────────────────────────
  Future<void> _exportCsv() async {
    if (_allDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Buat konten CSV
      final buffer = StringBuffer();
      buffer.writeln('No,Nama,Nomor HP'); // header

      for (int i = 0; i < _allDocs.length; i++) {
        final data = _allDocs[i].data() as Map<String, dynamic>;
        final nama = _escapeCsvField(data['nama'] ?? '');
        final noHp = _escapeCsvField(data['no_hp'] ?? '');
        buffer.writeln('${i + 1},$nama,$noHp');
      }

      final csvString = buffer.toString();
      final fileName = 'pelanggan_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        // Web: tidak ada akses filesystem — copy ke clipboard sebagai fallback
        // atau integrasikan dengan package universal_html untuk trigger download.
        // Untuk saat ini tampilkan snackbar informatif.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export CSV di web: gunakan share_plus atau universal_html',
            ),
          ),
        );
        return;
      }

      // Mobile / Desktop: simpan ke temp lalu share
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvString, encoding: utf8);

      await Share.shareXFiles([
        XFile(file.path, mimeType: 'text/csv'),
      ], subject: 'Data Pelanggan Laundry');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengekspor: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Escape nilai CSV: jika mengandung koma, kutip, atau newline → bungkus
  /// dengan double-quote dan escape kutip ganda menjadi dua kutip.
  String _escapeCsvField(dynamic value) {
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  String _normalizeNoHp(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.startsWith('62')) {
      cleaned = '0${cleaned.substring(2)}';
    }
    if (cleaned.startsWith('0') &&
        cleaned.length >= 9 &&
        cleaned.length <= 14 &&
        RegExp(r'^\d+$').hasMatch(cleaned)) {
      return cleaned;
    }
    return raw.trim();
  }

  Future<void> _pasteAndNormalize() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.isEmpty) return;

    final normalized = _normalizeNoHp(data.text!);
    _noHpCtrl.text = normalized;
    // Pindahkan cursor ke akhir
    _noHpCtrl.selection = TextSelection.collapsed(
      offset: _noHpCtrl.text.length,
    );
  }

  // ── Dialog Tambah / Edit Pelanggan ─────────────────────────────────────────
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
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Nomor HP',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: Tooltip(
                    message: 'Paste & konversi otomatis',
                    child: IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 18),
                      onPressed: _pasteAndNormalize,
                    ),
                  ),
                  helperText: 'Format +62 / 62 otomatis dikonversi ke 0xxx',
                  helperStyle: const TextStyle(fontSize: 11),
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

                final pelangganRef = _firestore
                    .collection('stores')
                    .doc(widget.storeId)
                    .collection('outlets')
                    .doc(widget.outletId)
                    .collection('pelanggan');
                if (isEdit) {
                  await pelangganRef.doc(docId).update({
                    'nama': nama,
                    'no_hp': noHp,
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                } else {
                  await pelangganRef.add({
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
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
          ],
          decoration: InputDecoration(
            labelText: 'Nomor HP',
            prefixIcon: const Icon(Icons.phone_outlined),
            suffixIcon: Tooltip(
              message: 'Paste & konversi otomatis',
              child: IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                onPressed: _pasteAndNormalize,
              ),
            ),
            helperText: 'Format +62 / 62 otomatis dikonversi ke 0xxx',
            helperStyle: const TextStyle(fontSize: 11),
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
              await _firestore
                  .collection('stores')
                  .doc(widget.storeId)
                  .collection('outlets')
                  .doc(widget.outletId)
                  .collection('pelanggan')
                  .doc(docId)
                  .update({
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
              await _firestore
                  .collection('stores')
                  .doc(widget.storeId)
                  .collection('outlets')
                  .doc(widget.outletId)
                  .collection('pelanggan')
                  .doc(docId)
                  .delete();
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

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('stores')
            .doc(widget.storeId)
            .collection('outlets')
            .doc(widget.outletId)
            .collection('pelanggan')
            .orderBy('nama')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Terjadi kesalahan saat memuat data'),
            );
          }

          if (snapshot.hasData) {
            final incoming = snapshot.data!.docs;
            if (_allDocs.length != incoming.length ||
                (incoming.isNotEmpty &&
                    (_allDocs.isEmpty ||
                        _allDocs.first.id != incoming.first.id))) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateDocs(incoming);
              });
            }
          }

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

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    // Gunakan warna dari tema agar kompatibel dengan dark mode
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor =
        colorScheme.surfaceContainerHighest; // abu di dark, abu muda di light

    return Container(
      // Ganti Colors.white → pakai surface dari tema
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Cari nama atau nomor HP...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          filled: true,
          // Ganti Colors.grey.shade100 → ikut tema
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
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
          actions: [
            // ── Tombol Export CSV ──
            _isExporting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Export CSV',
                    icon: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _exportCsv,
                  ),
          ],
        ),
      ),
    );
  }
}
