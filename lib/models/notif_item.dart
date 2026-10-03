import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Model notifikasi (sync dari Firestore) ──────────────────────────────────
class NotifItem {
  final String id;
  final String judul;
  final String isi;
  final DateTime waktu;
  bool sudahDibaca;

  NotifItem({
    required this.id,
    required this.judul,
    required this.isi,
    required this.waktu,
    this.sudahDibaca = false,
  });

  factory NotifItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotifItem(
      id: doc.id,
      judul: data['judul'] ?? '',
      isi: data['isi'] ?? '',
      waktu: (data['waktu'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sudahDibaca: data['sudahDibaca'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'judul': judul,
    'isi': isi,
    'waktu': Timestamp.fromDate(waktu),
    'sudahDibaca': sudahDibaca,
  };

  // Untuk backward compat dengan SharedPreferences (jika ada)
  factory NotifItem.fromJson(Map<String, dynamic> json) => NotifItem(
    id: json['id'] ?? '',
    judul: json['judul'] ?? '',
    isi: json['isi'] ?? '',
    waktu: DateTime.tryParse(json['waktu'] ?? '') ?? DateTime.now(),
    sudahDibaca: json['sudahDibaca'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'judul': judul,
    'isi': isi,
    'waktu': waktu.toIso8601String(),
    'sudahDibaca': sudahDibaca,
  };
}
