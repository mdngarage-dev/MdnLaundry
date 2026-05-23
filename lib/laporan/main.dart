import 'package:flutter/material.dart';
import '../screens/screens.dart';

class LaporanScreen extends StatelessWidget {
  const LaporanScreen({super.key});

  Widget _buildIndividualCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      // ✅ THEME: Warna card mengikuti tema
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          // ✅ THEME: Border mengikuti dividerColor tema
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // ✅ THEME: Background icon mengikuti primaryColor tema
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            // ✅ THEME: Warna icon mengikuti primaryColor tema
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            // ✅ THEME: Warna judul mengikuti tema
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            // ✅ THEME: Warna subtitle mengikuti tema
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          // ✅ THEME: Warna chevron mengikuti hintColor tema
          color: Theme.of(context).hintColor,
          size: 18,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildGroupedItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // ✅ THEME: Background icon mengikuti primaryColor tema (hijau-ish via opacity)
          color: Theme.of(context).primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          // ✅ THEME: Warna judul mengikuti tema
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          // ✅ THEME: Warna subtitle mengikuti tema
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).hintColor,
        size: 18,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      // ✅ THEME: Warna divider mengikuti tema
      color: Theme.of(context).dividerColor.withOpacity(0.5),
      indent: 65,
      endIndent: 15,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ THEME: Background mengikuti tema
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(
          "Laporan",
          style: TextStyle(
            // ✅ THEME: Warna teks AppBar mengikuti appBarTheme
            color:
                Theme.of(context).appBarTheme.titleTextStyle?.color ??
                Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // ✅ THEME: Warna AppBar mengikuti appBarTheme
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).primaryColor,
        elevation: 2,
        iconTheme: IconThemeData(
          color: Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),

            // ── Section: Ringkasan ──────────────────────────────────────
            Text(
              "RINGKASAN",
              style: TextStyle(
                // ✅ THEME: Warna label section mengikuti hintColor tema
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            _buildIndividualCard(
              context: context,
              icon: Icons.grid_view_rounded,
              title: "Ringkasan Klinik",
              subtitle: "Analisis performa bisnis lengkap",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RingkasanPage(),
                  ),
                );
              },
            ),

            _buildIndividualCard(
              context: context,
              icon: Icons.calendar_today_rounded,
              title: "Laporan Harian",
              subtitle: "Ringkasan transaksi hari ini",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LaporanHarianPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 25),

            // ── Section: Laporan Keuangan ───────────────────────────────
            Text(
              "DETAIL LAPORAN",
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                // ✅ THEME: Warna card grup mengikuti cardColor tema
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _buildGroupedItem(
                      context: context,
                      icon: Icons.shopping_bag_outlined,
                      title: "Pengeluaran",
                      subtitle: "Laporan detail pengeluaran",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ListPengeluaranPage(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(context),
                    _buildGroupedItem(
                      context: context,
                      icon: Icons.shopping_cart_outlined,
                      title: "Laporan Order",
                      subtitle: "Detail laporan order",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LaporanOrderPage(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(context),
                    _buildGroupedItem(
                      context: context,
                      icon: Icons.show_chart,
                      title: "Analisis Pelanggan",
                      subtitle: "Detail analisis pelanggan",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnalisisPelangganPage(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(context),
                    _buildGroupedItem(
                      context: context,
                      icon: Icons.co_present_outlined,
                      title: "Kinerja Pegawai",
                      subtitle: "Pantau kinerja pegawai",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KinerjaPegawaiPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
