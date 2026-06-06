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

  Future<File?> _loadLocalProfileImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = '${directory.path}/profile_pic_local.png';
      final file = File(imagePath);
      if (await file.exists()) return file;
    } catch (e) {
      debugPrint("Gagal memuat gambar di settings: $e");
    }
    return null;
  }

  String get _adminName {
    return user?.displayName ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final rawDisplayName = user?.displayName ?? "Nama Tidak Diatur|AdmLnd-005";
    final namaDanNip = rawDisplayName.split('|');
    final namaAdmin = namaDanNip[0].trim();
    final nipAdmin = namaDanNip.length > 1
        ? namaDanNip[1].trim()
        : "AdmLnd-005";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // ── Foto profil ────────────────────────────────────────────
            Center(
              child: FutureBuilder<File?>(
                future: _loadLocalProfileImage(),
                builder: (context, snapshot) {
                  final localImageFile = snapshot.data;
                  return CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).primaryColor,
                    backgroundImage: localImageFile != null
                        ? FileImage(localImageFile)
                        : (user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null)
                              as ImageProvider?,
                    child: localImageFile == null && user?.photoURL == null
                        ? const Icon(
                            Icons.person,
                            size: 70,
                            color: Colors.white,
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 25),

            // ── Stat cards — REAL-TIME via StreamBuilder ───────────────
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('order')
                  .where(
                    'admin',
                    isEqualTo: namaAdmin,
                  ) // pakai nama saja, bukan displayName penuh
                  .snapshots(),
              builder: (context, snapshot) {
                int totalDiterima = 0;
                int totalSelesai = 0;

                if (snapshot.hasData) {
                  final docs = snapshot.data!.docs;
                  totalDiterima = docs.length;

                  for (final doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status =
                        data['status']?.toString().toLowerCase() ?? '';
                    if (status == 'selesai') totalSelesai++;
                  }
                }

                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

                return Row(
                  children: [
                    _buildStatCard(
                      context,
                      isLoading ? '...' : totalDiterima.toString(),
                      'Laundry Diterima',
                      Icons.local_laundry_service_outlined,
                      Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 15),
                    _buildStatCard(
                      context,
                      isLoading ? '...' : totalSelesai.toString(),
                      'Laundry Selesai',
                      Icons.check_circle_outline_rounded,
                      Theme.of(context).primaryColor,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 25),

            // ── Informasi karyawan ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
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
                  _buildProfileField(
                    context,
                    "Nama Lengkap",
                    namaAdmin,
                    Icons.person_outline,
                  ),
                  _buildProfileField(
                    context,
                    "Email Sistem",
                    user?.email ?? "Email Tidak Ditemukan",
                    Icons.email_outlined,
                  ),
                  _buildProfileField(
                    context,
                    "NIP / ID Petugas",
                    nipAdmin,
                    Icons.badge_outlined,
                  ),
                  _buildProfileField(
                    context,
                    "Hak Akses",
                    _getUserRole(),
                    Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Tombol Edit Profile ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilPage()),
                  ).then((_) {
                    if (mounted) setState(() {});
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

  // ─── Widget Helpers ────────────────────────────────────────────

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
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
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

// Helper ambil role dari displayName
String _getUserRole() {
  final displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';
  final parts = displayName.split('|');
  return parts.length >= 3 ? parts[2] : 'Admin'; // index ke-2 = role
}
