import 'package:flutter/material.dart';
import '../screens/screens.dart';

class TentangAplikasiPage extends StatelessWidget {
  const TentangAplikasiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ✅ Satu variabel helper untuk warna teks muted
    final mutedColor = theme.textTheme.bodyLarge?.color?.withOpacity(0.5);

    return Scaffold(
      // ✅ Adaptive scaffold background
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // --- LOGO ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // ✅ cardColor adaptive
                color: theme.cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 45,
                backgroundColor: kPrimary.withOpacity(0.1),
                child: Icon(
                  Icons.local_hospital_rounded,
                  size: 50,
                  color: kPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- NAMA APLIKASI ---
            Text(
              "Klinik Ku Mobile",
              // ✅ Adaptive bold title
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // --- VERSI ---
            Text(
              "Versi ${AppConfig.appVersion}",
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 30),

            // --- KONTEN DESKRIPSI ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // ✅ cardColor adaptive
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                // ✅ Border adaptive via dividerColor
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Deskripsi Sistem",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Divider(height: 20, thickness: 1, color: theme.dividerColor),
                  Text(
                    "Klinik Ku Mobile adalah sistem manajemen internal klinik yang dirancang khusus untuk mempercepat proses rekam medis, pendaftaran pasien, serta pengelolaan laporan keuangan secara real-time.\n\n"
                    "Aplikasi ini terintegrasi langsung dengan ekosistem cloud untuk memastikan keamanan data pasien tetap terjaga, mempermudah pelacakan riwayat kunjungan, serta mendukung efisiensi operasional petugas admin dan tenaga medis di outlet.",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 14,
                      // ✅ Sedikit lebih muted dari teks utama
                      color: mutedColor,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- FOOTER ---
            Text(
              "© 2026 Klinik Ku. All Rights Reserved.\nPowored by : Rdh. Project",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 12,
                // ✅ Footer lebih redup dari teks biasa
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.35),
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final appBarTheme = Theme.of(context).appBarTheme;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: AppBar(
          // ✅ Judul & ikon dari appBarTheme
          title: Text(
            "Tentang Aplikasi",
            style:
                appBarTheme.titleTextStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          elevation: 2,
          centerTitle: true,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: appBarTheme.foregroundColor ?? Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
        ),
      ),
    );
  }
}
