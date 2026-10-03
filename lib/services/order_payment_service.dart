import 'package:cloud_firestore/cloud_firestore.dart';

/// Status pembayaran yang disimpan di dokumen `order` & `keuangan`.
class StatusBayar {
  static const belumBayar = 'belum_bayar';
  static const dp = 'dp';
  static const lunas = 'lunas';

  /// Tentukan status dari total yang sudah dibayar terhadap grand total.
  static String hitung({required int totalDibayar, required int grandTotal}) {
    if (grandTotal > 0 && totalDibayar >= grandTotal) return lunas;
    if (totalDibayar > 0) return dp;
    return belumBayar;
  }
}

class HasilPembayaran {
  final int totalDibayar;
  final int sisa;
  final String statusBayar;
  const HasilPembayaran({
    required this.totalDibayar,
    required this.sisa,
    required this.statusBayar,
  });
}

/// Satu-satunya tempat yang menulis data pembayaran order.
///
/// Struktur data (semua searah, order = sumber kebenaran):
///   order/{id}
///     status_bayar : belum_bayar | dp | lunas
///     dp_amount    : TOTAL yang sudah dibayar sampai saat ini (kumulatif)
///     harga_total  : grand total terakhir
///     pembayaran/{id}  : riwayat tiap pembayaran (nominal, metode, waktu, ...)
///   keuangan/{id}  : cermin dari order (biaya, dp_amount, status_bayar)
///                    → dipakai Laporan Harian
class OrderPaymentService {
  OrderPaymentService._();

  static final _db = FirebaseFirestore.instance;

  /// Catat pembayaran (sebagian atau pelunasan).
  static Future<HasilPembayaran> catatPembayaran({
    required String orderId,
    required String storeId,
    required String nomorPelanggan,
    required int grandTotal,
    required int sudahDibayar,
    required int nominal,
    String metode = 'Tunai',
    String catatan = '',
    String admin = '',
  }) async {
    final sisaSebelum = (grandTotal - sudahDibayar).clamp(0, grandTotal);
    // Tidak boleh bayar lebih dari sisa tagihan.
    final dibayarSekarang = nominal.clamp(0, sisaSebelum);
    if (dibayarSekarang <= 0) {
      throw ArgumentError('Nominal pembayaran tidak valid');
    }

    final totalBaru = sudahDibayar + dibayarSekarang;
    final status = StatusBayar.hitung(
      totalDibayar: totalBaru,
      grandTotal: grandTotal,
    );

    final orderRef = _db.collection('order').doc(orderId);
    final keuanganDocs = await _keuanganDocs(storeId, nomorPelanggan);

    final batch = _db.batch();
    batch.update(orderRef, {
      'status_bayar': status,
      'dp_amount': totalBaru,
      'harga_total': grandTotal,
    });
    batch.set(orderRef.collection('pembayaran').doc(), {
      'nominal': dibayarSekarang,
      'metode': metode,
      'catatan': catatan,
      'admin': admin,
      'total_dibayar_setelah': totalBaru,
      'sisa_setelah': grandTotal - totalBaru,
      'waktu': FieldValue.serverTimestamp(),
    });
    for (final doc in keuanganDocs) {
      batch.update(doc.reference, {
        'biaya': grandTotal,
        'dp_amount': totalBaru,
        'status_bayar': status,
      });
    }
    await batch.commit();

    return HasilPembayaran(
      totalDibayar: totalBaru,
      sisa: grandTotal - totalBaru,
      statusBayar: status,
    );
  }

  /// Dipanggil saat total order berubah (edit / tambah / hapus layanan).
  /// Menghitung ulang status bayar & menyamakan `keuangan` dengan `order`.
  static Future<String> sinkronSetelahTotalBerubah({
    required String orderId,
    required String storeId,
    required String nomorPelanggan,
    required int grandTotalBaru,
    required int sudahDibayar,
  }) async {
    final status = StatusBayar.hitung(
      totalDibayar: sudahDibayar,
      grandTotal: grandTotalBaru,
    );
    final keuanganDocs = await _keuanganDocs(storeId, nomorPelanggan);

    final batch = _db.batch();
    batch.update(_db.collection('order').doc(orderId), {
      'status_bayar': status,
      'dp_amount': sudahDibayar,
      'harga_total': grandTotalBaru,
    });
    for (final doc in keuanganDocs) {
      batch.update(doc.reference, {
        'biaya': grandTotalBaru,
        'dp_amount': sudahDibayar,
        'status_bayar': status,
      });
    }
    await batch.commit();
    return status;
  }

  /// Riwayat pembayaran (terbaru di atas).
  static Future<List<Map<String, dynamic>>> riwayat(String orderId) async {
    final snap = await _db
        .collection('order')
        .doc(orderId)
        .collection('pembayaran')
        .orderBy('waktu', descending: true)
        .get();
    return snap.docs.map((d) => {...d.data(), '_id': d.id}).toList();
  }

  /// Hapus semua data pembayaran milik order (dipakai saat hapus order).
  static Future<void> hapusSemua({
    required String orderId,
    required String storeId,
    required String nomorPelanggan,
  }) async {
    final riwayatSnap = await _db
        .collection('order')
        .doc(orderId)
        .collection('pembayaran')
        .get();
    for (final d in riwayatSnap.docs) {
      await d.reference.delete();
    }
    for (final d in await _keuanganDocs(storeId, nomorPelanggan)) {
      await d.reference.delete();
    }
  }

  /// `nomor_pelanggan` hanya unik per outlet/hari, jadi SELALU difilter
  /// dengan store_id supaya tidak menyentuh data toko lain.
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _keuanganDocs(String storeId, String nomorPelanggan) async {
    final snap = await _db
        .collection('keuangan')
        .where('store_id', isEqualTo: storeId)
        .where('nomor_pelanggan', isEqualTo: nomorPelanggan)
        .get();
    return snap.docs;
  }
}
