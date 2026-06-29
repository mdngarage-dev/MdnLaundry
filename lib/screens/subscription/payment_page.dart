import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mdnlaundry_project/services/payment_service.dart';
import 'package:mdnlaundry_project/services/subscription_service.dart';

class SubscriptionPaymentPage extends StatefulWidget {
  final String storeId;
  final String outletId;
  final String outletName;
  final VoidCallback onPaymentSuccess;
  final bool isUpgradeFlow;

  const SubscriptionPaymentPage({
    super.key,
    required this.storeId,
    required this.outletId,
    required this.outletName,
    required this.onPaymentSuccess,
    this.isUpgradeFlow = false,
  });

  @override
  State<SubscriptionPaymentPage> createState() =>
      _SubscriptionPaymentPageState();
}

class _SubscriptionPaymentPageState extends State<SubscriptionPaymentPage> {
  String _selectedPackage = 'basic';
  bool _isCreatingTransaction = false;
  Map<String, dynamic>? _currentTransaction;
  StreamSubscription? _paymentStatusSub;
  StreamSubscription? _subscriptionSub;
  DateTime? _initialUpdatedAt;
  String? _initialPlan;
  bool _baselineCaptured = false;

  @override
  void initState() {
    super.initState();
    _checkPendingPayment();
    _listenSubscriptionStatus();
  }

  @override
  void dispose() {
    _paymentStatusSub?.cancel();
    _subscriptionSub?.cancel();
    super.dispose();
  }

  // ── Cek pending payment sebelumnya ────────────────────────────────────────
  Future<void> _checkPendingPayment() async {
    final pending = await PaymentService.getLatestPendingPayment(
      storeId: widget.storeId,
      outletId: widget.outletId,
    );

    if (pending != null && mounted) {
      setState(() => _currentTransaction = pending);
      _listenPaymentStatus();
    }
  }

  // ── Listen subscription status → auto unlock saat lunas ──────────────────
  void _listenSubscriptionStatus() {
    _subscriptionSub =
        SubscriptionService.subscriptionStream(
          storeId: widget.storeId,
          outletId: widget.outletId,
        ).listen((snap) {
          if (!snap.exists || !mounted) return;
          final data = snap.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'unknown').toString();
          final plan = (data['plan'] ?? '').toString();
          final updatedAtRaw = data['updated_at'];
          final updatedAt = updatedAtRaw is Timestamp
              ? updatedAtRaw.toDate()
              : null;

          // ── Snapshot PERTAMA = baseline, jangan langsung trigger sukses ──
          if (!_baselineCaptured) {
            _baselineCaptured = true;
            _initialPlan = plan;
            _initialUpdatedAt = updatedAt;
            return; // ← jangan lakukan apa-apa di snapshot awal
          }

          // ── Snapshot BERIKUTNYA: cek apakah ini benar2 pembayaran baru ──
          final bool statusActive = status == 'active';
          final bool planBerubah = plan != _initialPlan;
          final bool waktuLebihBaru =
              updatedAt != null &&
              _initialUpdatedAt != null &&
              updatedAt.isAfter(_initialUpdatedAt!);

          if (statusActive && (planBerubah || waktuLebihBaru)) {
            // Ini transisi nyata akibat pembayaran baru → baru boleh auto-close
            widget.onPaymentSuccess();
          }
        });
  }

  // ── Listen payment record → update UI saat status berubah ────────────────
  void _listenPaymentStatus() {
    _paymentStatusSub?.cancel();
    _paymentStatusSub =
        PaymentService.paymentStatusStream(
          storeId: widget.storeId,
          outletId: widget.outletId,
        ).listen((snap) {
          if (snap.docs.isEmpty && mounted) {
            // Tidak ada pending payment lagi → kemungkinan sudah settlement
            setState(() => _currentTransaction = null);
          }
        });
  }

  // ── Create Midtrans QRIS Transaction ────────────────────────────────────
  Future<void> _createTransaction() async {
    setState(() => _isCreatingTransaction = true);

    try {
      final price = await PaymentService.getPackagePrice(_selectedPackage);

      if (price == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Harga paket tidak valid'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final result = await PaymentService.createMidtransTransaction(
        storeId: widget.storeId,
        outletId: widget.outletId,
        packageId: _selectedPackage,
        amount: price,
      );

      if (mounted) {
        setState(() {
          _currentTransaction = {
            'package_id': _selectedPackage,
            'amount': price,
            'qr_code_url': result['qr_code_url'] ?? '',
            'qr_string': result['qr_string'] ?? '',
            'order_id': result['order_id'] ?? '',
            'payment_record_id': result['payment_record_id'] ?? '',
            'status': 'pending',
          };
        });

        // Start listen payment status
        _listenPaymentStatus();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QRIS berhasil dibuat. Silakan scan untuk bayar.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal buat transaksi: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingTransaction = false);
    }
  }

  // ── Ganti paket → reset transaction ─────────────────────────────────────
  void _onChangePackage(String packageId) {
    if (_currentTransaction != null) {
      // Ada pending transaction → tanya user dulu
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Ganti Paket?'),
          content: const Text(
            'QRIS yang sudah dibuat akan dibatalkan. '
            'Apakah Anda yakin ingin ganti paket?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedPackage = packageId;
                  _currentTransaction = null;
                });
                _paymentStatusSub?.cancel();
              },
              child: const Text('Ganti'),
            ),
          ],
        ),
      );
    } else {
      setState(() => _selectedPackage = packageId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perpanjang Subscription'),
        centerTitle: true,
        elevation: 2,
        automaticallyImplyLeading: widget.isUpgradeFlow,
        leading: widget.isUpgradeFlow
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info Outlet ──────────────────────────────────────────────
            _buildOutletInfo(),
            const SizedBox(height: 20),

            // ── Subscription Expired Banner ──────────────────────────────
            if (!widget.isUpgradeFlow) ...[
              _buildExpiredBanner(),
              const SizedBox(height: 20),
            ],

            // ── Pilih Paket ──────────────────────────────────────────────
            Text(
              'Pilih Paket',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildPackageList(),
            const SizedBox(height: 20),

            // ── QRIS Section ─────────────────────────────────────────────
            if (_currentTransaction != null)
              _buildQrisSection()
            else
              _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildOutletInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.store_outlined,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.outletName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Perpanjang subscription untuk akses penuh',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Akses outlet terkunci karena subscription telah berakhir. '
              'Lakukan pembayaran untuk membuka akses kembali.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscription_packages')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final packages = snapshot.data!.docs;

        return Column(
          children: packages.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final packageId = doc.id;
            final name = data['name'] ?? 'Package';
            final price = data['price'] as int? ?? 0;
            final description = data['description'] ?? '';
            final features = data['features'] as Map<String, dynamic>? ?? {};
            final isSelected = _selectedPackage == packageId;

            return GestureDetector(
              onTap: () => _onChangePackage(packageId),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.08)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).dividerColor.withOpacity(0.5),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Radio<String>(
                          value: packageId,
                          groupValue: _selectedPackage,
                          onChanged: (val) {
                            if (val != null) _onChangePackage(val);
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          price == 0
                              ? 'Custom'
                              : NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(price),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),

                    // ── Feature List ───────────────────────────────────
                    if (isSelected && features.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildFeatureItem(
                        'Edit Nota',
                        features['edit_nota'] ?? false,
                      ),
                      _buildFeatureItem(
                        'Edit Pesan WA',
                        features['edit_wa_message'] ?? false,
                      ),
                      _buildFeatureItem(
                        'Input Order',
                        true,
                        value: features['order_limit'] == 999999
                            ? 'Unlimited'
                            : '${features['order_limit'] ?? 35}x/bulan',
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFeatureItem(String label, bool enabled, {String? value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: enabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: enabled ? null : Colors.grey),
          ),
          if (value != null) ...[
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrisSection() {
    final qrString = _currentTransaction!['qr_string'] as String? ?? '';
    final qrCodeUrl = _currentTransaction!['qr_code_url'] as String? ?? '';
    final amount = _currentTransaction!['amount'] as int? ?? 0;
    final orderId = _currentTransaction!['order_id'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scan QRIS untuk Bayar',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: Column(
            children: [
              // ── QR Code ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: qrString.isNotEmpty
                    // Render dari qr_string (raw QRIS string)
                    ? QrImageView(
                        data: qrString,
                        version: QrVersions.auto,
                        size: 240,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      )
                    // Fallback: load gambar QR dari Midtrans URL
                    : qrCodeUrl.isNotEmpty
                    ? Image.network(
                        qrCodeUrl,
                        width: 240,
                        height: 240,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            width: 240,
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                      )
                    : const SizedBox(
                        width: 240,
                        height: 240,
                        child: Center(child: Text('QR tidak tersedia')),
                      ),
              ),
              const SizedBox(height: 16),

              // ── Total Amount ──────────────────────────────────────────
              Text(
                NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(amount),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Order ID: $orderId',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // ── Status menunggu pembayaran ────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Menunggu pembayaran...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Info cara bayar ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cara Pembayaran',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildStep('1', 'Buka aplikasi mobile banking atau e-wallet'),
              _buildStep('2', 'Pilih menu Scan QR / QRIS'),
              _buildStep('3', 'Scan QR code di atas'),
              _buildStep(
                '4',
                'Konfirmasi pembayaran senilai Rp ${NumberFormat.decimalPattern('id').format(amount)}',
              ),
              _buildStep(
                '5',
                'Akses outlet akan terbuka otomatis setelah pembayaran berhasil',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Tombol Buat QRIS Baru ─────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _currentTransaction = null);
              _paymentStatusSub?.cancel();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Buat QRIS Baru'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isCreatingTransaction ? null : _createTransaction,
        icon: _isCreatingTransaction
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.qr_code_rounded),
        label: Text(
          _isCreatingTransaction ? 'Membuat QRIS...' : 'Bayar dengan QRIS',
        ),
      ),
    );
  }
}
