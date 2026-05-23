import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/screens.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

  int totalPasienDidaftar = 0;
  int totalInputMedis = 0;
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchStatsFromFirestore();
  }

  Future<void> _fetchStatsFromFirestore() async {
    try {
      String rawDisplayName = user?.displayName ?? "";
      String adminName = rawDisplayName.split('|')[0].trim();
      if (adminName.isEmpty) return;

      // ✅ Fetch rekam_medis berdasarkan admin_pemeriksa
      final rekamSnap = await FirebaseFirestore.instance
          .collection('rekam_medis')
          .where('admin_pemeriksa', isEqualTo: adminName)
          .get();

      // ✅ Input medis = jumlah dokumen rekam_medis oleh admin ini
      int jumlahInputMedis = rekamSnap.docs.length;

      // ✅ Pasien didaftar = jumlah NIP unik di rekam_medis oleh admin ini
      Set<String> nipUnik = {};
      for (var doc in rekamSnap.docs) {
        String nip = doc.data()['nomer_induk_pasien'] ?? "";
        if (nip.isNotEmpty) nipUnik.add(nip);
      }

      if (mounted) {
        setState(() {
          totalPasienDidaftar = nipUnik.length;
          totalInputMedis = jumlahInputMedis;
          isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Error Ambil Data Firestore: $e");
      if (mounted) setState(() => isLoadingStats = false);
    }
  }

  Future<File?> _loadLocalProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_pic_local.png';
      final file = File(imagePath);
      if (await file.exists()) return file;
    } catch (e) {
      print("Gagal memuat gambar di settings: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    String rawDisplayName = user?.displayName ?? "Nama Tidak Diatur|AdmMc-005";
    List<String> namaDanNip = rawDisplayName.split('|');
    String namaAdmin = namaDanNip[0];
    String nipAdmin = namaDanNip.length > 1 ? namaDanNip[1] : "AdmMc-005";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- FOTO PROFIL (LOCK SINKRON KE SETTINGS & READ-ONLY) ---
            Center(
              child: FutureBuilder<File?>(
                future:
                    _loadLocalProfileImage(), // Samakan pemanggilan fungsi dengan halaman setting
                builder: (context, snapshot) {
                  final localImageFile = snapshot.data;

                  return CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).primaryColor,
                    backgroundImage: localImageFile != null
                        ? FileImage(
                            localImageFile,
                          ) // ✅ Gunakan FileImage jika file lokal ditemukan
                        : (user?.photoURL != null
                                  ? NetworkImage(
                                      user!.photoURL!,
                                    ) // Cadangan jika ada URL dari Firebase
                                  : null)
                              as ImageProvider?,
                    child: localImageFile == null && user?.photoURL == null
                        ? const Icon(
                            Icons.person,
                            size: 70,
                            color: Colors.white,
                          ) // Default icon jika kosong
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 25),

            // --- KARTU PERFORMA KERJA ADMIN (REAL-TIME DATA) ---
            Row(
              children: [
                _buildStatCard(
                  context,
                  isLoadingStats ? "..." : totalPasienDidaftar.toString(),
                  "Pasien Didaftar",
                  Icons.people,
                  Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 15),
                _buildStatCard(
                  context,
                  isLoadingStats ? "..." : totalInputMedis.toString(),
                  "Input Medis",
                  Icons.assignment_turned_in,
                  Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 25),

            // --- DETAIL INFORMASI PERSONAL ADMIN (READ-ONLY) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // 🟢 Tembak langsung ke cardColor tema global Anda
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.2
                          : 0.02,
                    ),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "INFORMASI KARYAWAN",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Divider(height: 20),

                  // 🟢 Menampilkan Nama Lengkap asli dari Firebase Auth
                  _buildProfileField(
                    context,
                    "Nama Lengkap",
                    namaAdmin,
                    Icons.person_outline,
                  ),

                  // 🟢 OTOMATIS: Menampilkan Email asli dari akun Firebase Auth yang sedang login
                  _buildProfileField(
                    context,
                    "Email Sistem",
                    user?.email ?? "Email Tidak Ditemukan",
                    Icons.email_outlined,
                  ),

                  _buildProfileField(
                    context,
                    "NIP / ID Petugas",
                    nipAdmin, // Bisa disesuaikan dinamis jika ada datanya di Sheet/Auth
                    Icons.badge_outlined,
                  ),
                  _buildProfileField(
                    context,
                    "Hak Akses",
                    "Super Admin",
                    Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Tombol Sign Out ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilPage()),
                  ).then((_) {
                    if (mounted) {
                      setState(() {}); // Tetap nge-refresh pas balik
                    }
                  });
                },
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text(
                  "Edit Profile",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          // 🟢 Tembak langsung ke cardColor tema global Anda
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              // 🟢 Tembak langsung ke textTheme.bodyLarge global Anda
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 22),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                // 🟢 Tembak langsung ke textTheme.bodyLarge global Anda
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: AppBar(
          title: const Text(
            "Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
