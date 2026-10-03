import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────
class Layanan {
  final String id;
  final String nama;
  final String tipe; // 'satuan' | 'kiloan' | 'meter'
  final double harga;
  final int durasiJam; // selalu disimpan dalam jam

  const Layanan({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.harga,
    required this.durasiJam,
  });

  factory Layanan.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Layanan(
      id: doc.id,
      nama: d['nama'] ?? '',
      tipe: d['tipe'] ?? 'kiloan',
      harga: (d['harga'] ?? 0).toDouble(),
      durasiJam: d['durasi_jam'] ?? 24,
    );
  }

  Map<String, dynamic> toMap() => {
    'nama': nama,
    'tipe': tipe,
    'harga': harga,
    'durasi_jam': durasiJam,
  };
}
