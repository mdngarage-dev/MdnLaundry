import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/screens/main_screens.dart';
import 'package:mdnlaundry_project/screens/outlet/outlet_service.dart';

class LaporanScreen extends StatefulWidget {
  final String storeId;
  final String outletId;
  final bool isOwner;

  const LaporanScreen({
    super.key,
    required this.storeId,
    required this.outletId,
    this.isOwner = false,
  });

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  late String _selectedView; // 'outlet' atau 'gabungan'
  late String _selectedOutletId;
  String _selectedMonth = DateTime.now().toString().substring(0, 7);

  @override
  void initState() {
    super.initState();
    _selectedView = widget.isOwner ? 'outlet' : 'outlet';
    _selectedOutletId = widget.outletId;
  }

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
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
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
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
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
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).hintColor,
          size: 18,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withOpacity(0.5),
      indent: 65,
      endIndent: 15,
    );
  }

  Widget _buildOutletSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('outlets')
          .orderBy('is_utama', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final outlets = snapshot.data!.docs;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: DropdownButton<String>(
            value: _selectedOutletId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: outlets
                .map(
                  (outlet) => DropdownMenuItem(
                    value: outlet.id,
                    child: Text(outlet['nama_outlet'] ?? 'Outlet'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedOutletId = value);
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Laporan",
          style: TextStyle(
            color:
                Theme.of(context).appBarTheme.titleTextStyle?.color ??
                Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
            // ── Filter Section (Owner only) ────────────────────────────
            if (widget.isOwner) ...[
              const SizedBox(height: 16),
              Text(
                'Tampilkan Laporan',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedView = 'outlet'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedView == 'outlet'
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              bottomLeft: Radius.circular(11),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Per Outlet',
                              style: TextStyle(
                                color: _selectedView == 'outlet'
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedView = 'gabungan'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedView == 'gabungan'
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(11),
                              bottomRight: Radius.circular(11),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Gabungan',
                              style: TextStyle(
                                color: _selectedView == 'gabungan'
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Outlet Selector (jika per outlet) ──────────────────
              if (_selectedView == 'outlet') ...[
                Text(
                  'Outlet',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _buildOutletSelector(),
                const SizedBox(height: 16),
              ],
            ],

            // ── Section: Ringkasan ──────────────────────────────────────
            FutureBuilder<List<bool>>(
              future: Future.wait([
                canAccess('can_access_ringkasan'),
                canAccess('can_access_harian'),
              ]),
              builder: (context, snapshot) {
                final anyVisible = (snapshot.data ?? []).any((v) => v == true);
                if (!anyVisible) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 15),
                    Text(
                      "RINGKASAN",
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),

            // ── Ringkasan Outlet ─────────────────────────────────────
            FutureBuilder<bool>(
              future: canAccess('can_access_ringkasan'),
              builder: (context, snapshot) {
                if (!(snapshot.data ?? false)) return const SizedBox.shrink();
                return _buildIndividualCard(
                  context: context,
                  icon: Icons.grid_view_rounded,
                  title: "Ringkasan Outlet",
                  subtitle: "Analisis performa bisnis lengkap",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RingkasanPage(
                          storeId: widget.storeId,
                          outletId: _selectedView == 'gabungan'
                              ? ''
                              : _selectedOutletId,
                          isGabungan: _selectedView == 'gabungan',
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // ── Laporan Harian ──────────────────────────────────────
            FutureBuilder<bool>(
              future: canAccess('can_access_harian'),
              builder: (context, snapshot) {
                if (!(snapshot.data ?? false)) return const SizedBox.shrink();
                return _buildIndividualCard(
                  context: context,
                  icon: Icons.calendar_today_rounded,
                  title: "Laporan Harian",
                  subtitle: "Ringkasan transaksi hari ini",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LaporanHarianPage(
                          storeId: widget.storeId,
                          outletId: _selectedView == 'gabungan'
                              ? ''
                              : _selectedOutletId,
                          isGabungan: _selectedView == 'gabungan',
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // ── Jarak ───────────────────────────────────────────────
            FutureBuilder<List<bool>>(
              future: Future.wait([
                canAccess('can_access_ringkasan'),
                canAccess('can_access_harian'),
              ]),
              builder: (context, snapshot) {
                final anyVisible = (snapshot.data ?? []).any((v) => v == true);
                return SizedBox(height: anyVisible ? 0 : 25);
              },
            ),

            // ── Section: Detail Laporan ─────────────────────────────
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
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      // ── Tambah Pengeluaran ──────────────────────────
                      // Hanya untuk Admin yang TIDAK punya akses penuh ke
                      // halaman "Pengeluaran" (can_access_lispengeluaran).
                      // Owner tidak pernah lihat card ini sama sekali, dan
                      // admin yang sudah punya akses penuh juga tidak —
                      // karena halaman "Pengeluaran" sudah punya tombol
                      // tambah sendiri di dalamnya.
                      FutureBuilder<bool>(
                        future: canAccess('can_access_lispengeluaran'),
                        builder: (context, snapshot) {
                          final sudahPunyaAksesPengeluaran =
                              snapshot.data ?? false;
                          final isOwnerSekarang = getUserRole() == 'Owner';

                          if (isOwnerSekarang || sudahPunyaAksesPengeluaran) {
                            return const SizedBox.shrink();
                          }

                          return _buildGroupedItem(
                            context: context,
                            icon: Icons.shopping_bag_outlined,
                            title: "Tambah Pengeluaran",
                            subtitle: "Halaman Input pengeluaran",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FormPengeluaranPage(
                                    storeId: widget.storeId,
                                    outletId: _selectedView == 'gabungan'
                                        ? ''
                                        : _selectedOutletId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // ── Pengeluaran ─────────────────────────────────
                      FutureBuilder<bool>(
                        future: canAccess('can_access_lispengeluaran'),
                        builder: (context, snapshot) {
                          if (!(snapshot.data ?? false))
                            return const SizedBox.shrink();
                          return _buildGroupedItem(
                            context: context,
                            icon: Icons.shopping_bag_outlined,
                            title: "Pengeluaran",
                            subtitle: "Laporan detail pengeluaran",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ListPengeluaranPage(
                                    storeId: widget.storeId,
                                    outletId: _selectedView == 'gabungan'
                                        ? ''
                                        : _selectedOutletId,
                                    isGabungan: _selectedView == 'gabungan',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      _buildDivider(context),

                      // ── Laporan Order ───────────────────────────────
                      _buildGroupedItem(
                        context: context,
                        icon: Icons.shopping_cart_outlined,
                        title: "Laporan Order",
                        subtitle: "Detail laporan order",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LaporanOrderPage(
                                storeId: widget.storeId,
                                outletId: _selectedView == 'gabungan'
                                    ? ''
                                    : _selectedOutletId,
                                isGabungan: _selectedView == 'gabungan',
                              ),
                            ),
                          );
                        },
                      ),

                      _buildDivider(context),

                      // ── Analisis Pelanggan ──────────────────────────
                      _buildGroupedItem(
                        context: context,
                        icon: Icons.show_chart,
                        title: "Analisis Pelanggan",
                        subtitle: "Detail analisis pelanggan",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnalisisPelangganPage(
                                storeId: widget.storeId,
                                outletId: _selectedView == 'gabungan'
                                    ? ''
                                    : _selectedOutletId,
                              ),
                            ),
                          );
                        },
                      ),

                      _buildDivider(context),

                      // ── Kinerja Pegawai ────────────────────────────
                      _buildGroupedItem(
                        context: context,
                        icon: Icons.co_present_outlined,
                        title: "Kinerja Pegawai",
                        subtitle: "Pantau kinerja pegawai",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KinerjaPegawaiPage(
                                storeId: widget.storeId,
                                outletId: _selectedView == 'gabungan'
                                    ? ''
                                    : _selectedOutletId,
                                isGabungan: _selectedView == 'gabungan',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
