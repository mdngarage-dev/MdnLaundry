import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mdnlaundry_project/components/notif_laundry.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main_screens.dart';
import '../screens/outlet/outlet_management.dart';
import '../screens/outlet/outlet_selector.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _selectedIndex = 0;
  String _storeId = '';
  String _currentOutletId = '';
  String _currentOutletName = '';
  String _ownerNoHp = '';
  bool _isLoading = true;
  bool _isOwner = false;
  StreamSubscription? _userListener;
  StreamSubscription? _outletListener;

  @override
  void initState() {
    super.initState();
    _getStoreAndOutlet();
    _listenUserStatus();
  }

  @override
  void dispose() {
    _userListener?.cancel();
    _outletListener?.cancel();
    super.dispose();
  }

  // ── Auto logout jika dokumen user dihapus ────────────────────────────────
  void _listenUserStatus() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _userListener = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
          if (!snap.exists) {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            }
          }
        });
  }

  Future<void> _fetchOwnerNoHp(String storeId) async {
    try {
      final outletSnap = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('outlets')
          .where('is_utama', isEqualTo: true)
          .limit(1)
          .get();

      if (outletSnap.docs.isNotEmpty) {
        final noHp = outletSnap.docs.first['no_hp']?.toString() ?? '';
        if (mounted) setState(() => _ownerNoHp = noHp);
      }
    } catch (e) {
      debugPrint('Gagal fetch no_hp outlet: $e');
    }
  }

  // ── Load store_id, role, dan current_outlet_id ───────────────────────────
  Future<void> _getStoreAndOutlet() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};
      final storeId = data['store_id'] ?? '';
      final role = data['role'] ?? '';
      final currentOutletId = data['current_outlet_id'] ?? '';
      final isActivated = data['is_activated'] ?? false;

      // Admin belum diaktivasi → tampilkan halaman tunggu
      if (role == 'Admin' && !isActivated) {
        if (storeId.isNotEmpty) await _fetchOwnerNoHp(storeId);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Owner belum punya current_outlet_id → ambil outlet utama
      if (role == 'Owner' && currentOutletId.isEmpty) {
        final outletSnap = await FirebaseFirestore.instance
            .collection('stores')
            .doc(storeId)
            .collection('outlets')
            .where('is_utama', isEqualTo: true)
            .limit(1)
            .get();

        if (outletSnap.docs.isNotEmpty) {
          final outletId = outletSnap.docs.first.id;
          final outletName = outletSnap.docs.first['nama_outlet'] ?? 'Outlet';

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'current_outlet_id': outletId});

          if (storeId.isNotEmpty) {
            await OutletSettingsService.load(storeId, outletId);
            await PrinterSettingsService.load(storeId, outletId);
          }

          // ── Set tag OneSignal untuk targeting notif ─────────────────────
          await NotifLaundryService().setUserTags(
            storeId: storeId,
            role: 'Owner',
            currentOutletId: outletId,
          );

          if (mounted) {
            setState(() {
              _storeId = storeId;
              _currentOutletId = outletId;
              _currentOutletName = outletName;
              _isOwner = true;
              _isLoading = false;
            });
            _listenToOutlet(storeId, outletId);
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
        return;
      }

      // Load nama outlet real-time
      if (storeId.isNotEmpty && currentOutletId.isNotEmpty) {
        await OutletSettingsService.load(storeId, currentOutletId);
        await PrinterSettingsService.load(storeId, currentOutletId);
        _listenToOutlet(storeId, currentOutletId);
      }

      // ── Set tag OneSignal untuk targeting notif ───────────────────────────
      if (storeId.isNotEmpty && currentOutletId.isNotEmpty) {
        await NotifLaundryService().setUserTags(
          storeId: storeId,
          role: role == 'Owner' ? 'Owner' : 'Admin',
          currentOutletId: currentOutletId,
        );
      }

      if (mounted) {
        setState(() {
          _storeId = storeId;
          _currentOutletId = currentOutletId;
          _isOwner = role == 'Owner';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal load store & outlet: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Listen real-time nama outlet ─────────────────────────────────────────
  void _listenToOutlet(String storeId, String outletId) {
    _outletListener?.cancel();
    _outletListener = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('outlets')
        .doc(outletId)
        .snapshots()
        .listen((snap) {
          if (snap.exists && mounted) {
            setState(() {
              _currentOutletName = snap['nama_outlet'] ?? 'Outlet';
            });
          }
        });
  }

  // ── Switch outlet ─────────────────────────────────────────────────────────
  Future<void> _switchOutlet(String outletId, String outletName) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'current_outlet_id': outletId,
      });

      await OutletSettingsService.load(_storeId, outletId);
      await PrinterSettingsService.load(_storeId, outletId);

      _listenToOutlet(_storeId, outletId);

      // ── Update tag OneSignal current_outlet_id saat switch outlet ─────────
      await NotifLaundryService().setUserTags(
        storeId: _storeId,
        role: _isOwner ? 'Owner' : 'Admin',
        currentOutletId: outletId,
      );

      if (mounted) {
        setState(() {
          _currentOutletId = outletId;
          _currentOutletName = outletName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Outlet berubah ke: $outletName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal switch outlet: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Buka dialog pilih outlet ──────────────────────────────────────────────
  void _showOutletSelector() {
    showDialog(
      context: context,
      builder: (ctx) => OutletSelectorDialog(
        storeId: _storeId,
        currentOutletId: _currentOutletId,
        onOutletSelected: _switchOutlet,
      ),
    );
  }

  List<Widget> get _screens => [
    HomeScreen(
      storeId: _storeId,
      outletId: _currentOutletId,
      outletName: _currentOutletName,
      onSwitchOutlet: _showOutletSelector,
      isOwner: _isOwner,
    ),
    OrderScreen(storeId: _storeId, outletId: _currentOutletId),
    AddOrderScreen(storeId: _storeId, outletId: _currentOutletId),
    LaporanScreen(
      storeId: _storeId,
      outletId: _currentOutletId,
      isOwner: _isOwner,
    ),
    SettingScreen(
      storeId: _storeId,
      outletId: _currentOutletId,
      isOwner: _isOwner,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Loading
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Admin belum diaktivasi
    if (!_isOwner && _currentOutletId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tunggu Aktivasi',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor:
              Theme.of(context).appBarTheme.backgroundColor ?? kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: null,
                            strokeWidth: 3,
                            color: kPrimary.withOpacity(0.3),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.hourglass_bottom_rounded,
                            size: 38,
                            color: kPrimary,
                          ),
                        ),
                      ],
                    );
                  },
                  onEnd: () => setState(() {}),
                ),
                const SizedBox(height: 32),
                Text(
                  'Akun Anda Sedang Menunggu',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Admin ini sedang menunggu Owner untuk mengaktifkan akses ke outlet. Hubungi Owner Anda.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_ownerNoHp.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      final namaAdmin = (user?.displayName ?? 'Admin')
                          .split('|')[0]
                          .trim();

                      String noHp = _ownerNoHp.replaceAll(
                        RegExp(r'[\s\-]'),
                        '',
                      );
                      if (noHp.startsWith('0')) {
                        noHp = '62${noHp.substring(1)}';
                      } else if (noHp.startsWith('+')) {
                        noHp = noHp.substring(1);
                      }

                      final pesan = Uri.encodeComponent(
                        'Halo Owner, saya $namaAdmin. '
                        'Akun Admin saya sudah terdaftar dan sedang menunggu aktivasi. '
                        'Mohon segera aktifkan akses saya ke outlet. Terima kasih 🙏',
                      );

                      final url = Uri.parse('https://wa.me/$noHp?text=$pesan');

                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tidak bisa membuka WhatsApp'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF25D366).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hubungi Owner via WhatsApp',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF25D366),
                                ),
                              ),
                              Text(
                                _ownerNoHp,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: const Color(0xFF25D366).withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _getStoreAndOutlet();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Cek Status'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: BorderSide(color: kPrimary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await NotifLaundryService().clearUserTags();
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Store / outlet tidak ditemukan
    if (_storeId.isEmpty || _currentOutletId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Store atau Outlet tidak ditemukan.\nHubungi admin.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: CustomBottomNav(
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
