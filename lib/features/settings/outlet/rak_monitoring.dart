import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:mdnlaundry_project/core/app_exports.dart';
import 'package:mdnlaundry_project/core/utils/format_utils.dart';

// ════════════════════════════════════════════════════════════════════════════
//  RAK MONITORING SCREEN
// ════════════════════════════════════════════════════════════════════════════
class RakMonitoringScreen extends StatefulWidget {
  final String storeId;
  final String outletId;
  const RakMonitoringScreen({
    super.key,
    required this.storeId,
    required this.outletId,
  });

  @override
  State<RakMonitoringScreen> createState() => _RakMonitoringScreenState();
}

class _RakMonitoringScreenState extends State<RakMonitoringScreen> {
  late final Stream<QuerySnapshot> _orderStream;
  late final Stream<QuerySnapshot> _rakStream;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance
        .collection('order')
        .where('store_id', isEqualTo: widget.storeId)
        .where('outlet_id', isEqualTo: widget.outletId)
        .where('status', isEqualTo: 'siap ambil')
        .snapshots();
    _rakStream = FirebaseFirestore.instance
        .collection('rak')
        .where('store_id', isEqualTo: widget.storeId)
        .where('outlet_id', isEqualTo: widget.outletId)
        .orderBy('urutan')
        .snapshots();
  }

  // ── FAB: Tambah Rak ────────────────────────────────────────────────────────
  void _showTambahRakDialog() {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_box_outlined,
                color: Color(0xFF0D9488),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Tambah Rak',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Contoh: Rak 1, Rak VIP, Rak Ekspres',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF0D9488),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama rak wajib diisi' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _tambahRak(ctrl.text.trim());
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'Tambah',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _tambahRak(String nama) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rak')
          .where('store_id', isEqualTo: widget.storeId)
          .where('outlet_id', isEqualTo: widget.outletId)
          .get();
      await FirebaseFirestore.instance.collection('rak').add({
        'nama': nama,
        'urutan': snap.docs.length + 1,
        'store_id': widget.storeId,
        'outlet_id': widget.outletId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rak "$nama" berhasil ditambahkan'),
          backgroundColor: const Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menambahkan rak: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: AppBar(
            title: const Text(
              'Monitoring Rak',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor:
                Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
            foregroundColor:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
            elevation: 2,
            centerTitle: true,
          ),
        ),
      ),

      // ── FAB Tambah Rak ──────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTambahRakDialog,
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Tambah Rak',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _rakStream,
        builder: (context, rakSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: _orderStream,
            builder: (context, orderSnap) {
              if (!rakSnap.hasData || !orderSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                );
              }

              final rakDocs = rakSnap.data!.docs;
              final orderDocs = orderSnap.data!.docs;

              // Map: rakId → list of order docs
              final Map<String, List<QueryDocumentSnapshot>> rakOrders = {};
              final List<QueryDocumentSnapshot> tanpaRak = [];

              for (final order in orderDocs) {
                final data = order.data() as Map<String, dynamic>;
                final rakId = data['rak_id']?.toString() ?? '';
                if (rakId.isEmpty) {
                  tanpaRak.add(order);
                } else {
                  rakOrders.putIfAbsent(rakId, () => []).add(order);
                }
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Ringkasan ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${orderDocs.length} order ',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'siap ambil · ${rakDocs.length} rak aktif',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Card per rak ────────────────────────────────────────
                  ...rakDocs.map((rakDoc) {
                    final rakData = rakDoc.data() as Map<String, dynamic>;
                    final rakNama = rakData['nama']?.toString() ?? '-';
                    final orders = rakOrders[rakDoc.id] ?? [];

                    return _RakCard(
                      rakId: rakDoc.id,
                      rakNama: rakNama,
                      orders: orders,
                      isDark: isDark,
                      primary: primary,
                      storeId: widget.storeId,
                      outletId: widget.outletId,
                    );
                  }),

                  // ── Order tanpa rak ─────────────────────────────────────
                  if (tanpaRak.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _RakCard(
                      rakId: '',
                      rakNama: 'Tanpa Rak',
                      orders: tanpaRak,
                      isDark: isDark,
                      primary: Colors.orange.shade700,
                      isWarning: true,
                      storeId: widget.storeId,
                      outletId: widget.outletId,
                    ),
                  ],

                  // ── Empty state ─────────────────────────────────────────
                  if (orderDocs.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 56,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tidak ada cucian di rak',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Semua cucian sudah diambil pelanggan',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIDGET CARD TIAP RAK
// ════════════════════════════════════════════════════════════════════════════
class _RakCard extends StatefulWidget {
  final String rakId;
  final String rakNama;
  final List<QueryDocumentSnapshot> orders;
  final bool isDark;
  final Color primary;
  final bool isWarning;
  final String storeId;
  final String outletId;

  const _RakCard({
    required this.rakId,
    required this.rakNama,
    required this.orders,
    required this.isDark,
    required this.primary,
    required this.storeId,
    required this.outletId,
    this.isWarning = false,
  });

  @override
  State<_RakCard> createState() => _RakCardState();
}

class _RakCardState extends State<_RakCard> {
  bool _expanded = true;

  // ── Edit nama rak ──────────────────────────────────────────────────────────
  void _showEditDialog() {
    final ctrl = TextEditingController(text: widget.rakNama);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit_outlined, color: widget.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Edit Nama Rak',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nama rak baru',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama rak wajib diisi' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await _simpanEditRak(ctrl.text.trim());
            },
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text(
              'Simpan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _simpanEditRak(String namaBaru) async {
    try {
      // Update nama rak di collection 'rak'
      await FirebaseFirestore.instance
          .collection('rak')
          .doc(widget.rakId)
          .update({'nama': namaBaru});

      // Sync rak_nama di semua order yang pakai rak ini
      final ordersSnap = await FirebaseFirestore.instance
          .collection('order')
          .where('store_id', isEqualTo: widget.storeId)
          .where('rak_id', isEqualTo: widget.rakId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in ordersSnap.docs) {
        batch.update(doc.reference, {'rak_nama': namaBaru});
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nama rak diperbarui menjadi "$namaBaru"'),
          backgroundColor: widget.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah nama rak: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Hapus rak ──────────────────────────────────────────────────────────────
  void _showHapusDialog() {
    final adaOrder = widget.orders.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 10),
            Text(
              'Hapus Rak',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: adaOrder
            ? RichText(
                text: TextSpan(
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.6),
                  children: [
                    const TextSpan(text: 'Rak ini masih berisi '),
                    TextSpan(
                      text: '${widget.orders.length} order',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text:
                          ' yang belum diambil.\n\nHapus rak tetap bisa dilakukan, tapi order-order tersebut akan menjadi ',
                    ),
                    const TextSpan(
                      text: 'Tanpa Rak',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              )
            : RichText(
                text: TextSpan(
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.6),
                  children: [
                    const TextSpan(text: 'Yakin ingin menghapus rak '),
                    TextSpan(
                      text: '"${widget.rakNama}"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '?\n\n'),
                    const TextSpan(
                      text: 'Tindakan ini tidak dapat dibatalkan.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _hapusRak();
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text(
              'Ya, Hapus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusRak() async {
    try {
      // Kosongkan rak_id di semua order yang pakai rak ini
      if (widget.orders.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final order in widget.orders) {
          batch.update(order.reference, {
            'rak_id': FieldValue.delete(),
            'rak_nama': FieldValue.delete(),
            'waktu_masuk_rak': FieldValue.delete(),
          });
        }
        await batch.commit();
      }

      // Hapus dokumen rak
      await FirebaseFirestore.instance
          .collection('rak')
          .doc(widget.rakId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rak "${widget.rakNama}" berhasil dihapus'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus rak: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.orders.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: widget.isWarning
            ? Border.all(color: Colors.orange.shade300)
            : null,
      ),
      child: Column(
        children: [
          // ── Header rak ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                // Icon rak
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.isWarning
                        ? Icons.warning_amber_rounded
                        : Icons.shelves,
                    color: widget.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Nama & jumlah — bisa tap untuk expand/collapse
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.rakNama,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                        ),
                        Text(
                          isEmpty ? 'Kosong' : '${widget.orders.length} order',
                          style: TextStyle(
                            color: isEmpty
                                ? Colors.grey.shade400
                                : widget.primary,
                            fontSize: 12,
                            fontWeight: isEmpty
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Badge jumlah
                if (!isEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.orders.length}',
                      style: TextStyle(
                        color: widget.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // ── Tombol Edit (sembunyikan untuk card "Tanpa Rak") ─────────
                if (!widget.isWarning) ...[
                  _iconBtn(
                    icon: Icons.edit_outlined,
                    color: widget.primary,
                    tooltip: 'Edit nama rak',
                    onTap: _showEditDialog,
                  ),
                  const SizedBox(width: 2),
                  _iconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.red,
                    tooltip: 'Hapus rak',
                    onTap: _showHapusDialog,
                  ),
                  const SizedBox(width: 2),
                ],

                // Chevron expand/collapse
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── List order dalam rak ─────────────────────────────────────────
          if (_expanded && !isEmpty) ...[
            const Divider(height: 1),
            ...widget.orders.map((orderDoc) {
              final data = orderDoc.data() as Map<String, dynamic>;
              final noPelanggan = data['nomor_pelanggan']?.toString() ?? '-';
              final nama = data['nama_pelanggan']?.toString() ?? '-';
              final noHp = data['no_hp']?.toString() ?? '';
              final layanan = data['layanan_nama']?.toString() ?? '-';
              final statusBayar =
                  data['status_bayar']?.toString().toLowerCase() ?? '';
              final belumLunas = statusBayar != 'lunas';
              final harga = data['harga_total'] ?? data['harga_satuan'];

              String waktuMasuk = '-';
              final wm = data['waktu_masuk_rak'];
              if (wm is Timestamp) {
                waktuMasuk = DateFormat('dd/MM HH:mm').format(wm.toDate());
              }

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      docId: orderDoc.id,
                      data: data,
                      storeId: widget.storeId,
                      outletId: widget.outletId,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.4),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D9488),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  noPelanggan,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '· $nama',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              layanan,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                            if (noHp.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 10,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    noHp,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            waktuMasuk,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          if (belumLunas)
                            _statusBadge(
                              label: harga != null
                                  ? formatRupiah(harga)
                                  : 'Belum Bayar',
                              color: Colors.orange.shade700,
                            )
                          else
                            _statusBadge(label: 'Lunas', color: Colors.green),
                          const SizedBox(height: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          if (_expanded && isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rak kosong',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Helper: icon button kecil ───────────────────────────────────────────────
  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      ),
    );
  }

  // ── Helper: badge status ───────────────────────────────────────────────────
  Widget _statusBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Helper format rupiah ──────────────────────────────────────────────────────
