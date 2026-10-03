import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Global Role & Permission Helpers
// ─────────────────────────────────────────────────────────────────────────────

String getUserRole() {
  final displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';
  final parts = displayName.split('|');
  return parts.length >= 3 ? parts[2] : 'Admin';
}

Future<bool> canAccess(String key, {bool ownerOnly = false}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final role = getUserRole();

  // Khusus Admin saja (Owner tidak tampil)
  if (ownerOnly) return role == 'Admin';

  // Owner selalu bisa
  if (role == 'Owner') return true;

  // Admin — cek izin di store_permissions/{storeId}/{outletId}/{uid}
  // (BUKAN di users/{uid} — itu cuma menyimpan data profil/role/store_id,
  // tidak pernah diisi field izin seperti can_access_layanan dsb. Field
  // izin ditulis oleh EditAdminPermissionScreen ke collection terpisah ini.)
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (userData == null) return false;

    final storeId = userData['store_id'] ?? '';
    final outletId = userData['current_outlet_id'] ?? '';
    if (storeId.isEmpty || outletId.isEmpty) return false;

    final permDoc = await FirebaseFirestore.instance
        .collection('store_permissions')
        .doc(storeId)
        .collection(outletId)
        .doc(user.uid)
        .get();

    return permDoc.data()?[key] ?? false;
  } catch (e) {
    return false;
  }
}
