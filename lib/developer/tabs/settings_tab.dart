import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Account Info ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Information',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final userData =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSettingItem('Name', userData?['nama'] ?? 'N/A'),
                      _buildSettingItem('Email', userData?['email'] ?? 'N/A'),
                      _buildSettingItem('Role', userData?['role'] ?? 'N/A'),
                      _buildSettingItem(
                        'Joined',
                        userData?['created_at'] != null
                            ? DateFormat('dd MMM yyyy').format(
                                (userData?['created_at'] as Timestamp).toDate(),
                              )
                            : 'N/A',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Subscription Packages ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription Packages',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('subscription_packages')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final packages = snapshot.data!.docs;
                  return Column(
                    children: packages.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final packageId = doc.id;
                      final name = data['name'] ?? 'Package';
                      final price = data['price'] ?? 0;
                      final active = data['active'] ?? true;
                      final description = data['description'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: active
                                                    ? Colors.green.withOpacity(
                                                        0.1,
                                                      )
                                                    : Colors.grey.withOpacity(
                                                        0.1,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                active ? 'Aktif' : 'Nonaktif',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: active
                                                      ? Colors.green.shade700
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            description,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
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
                                      fontSize: 14,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              // ── Features preview ──────────────────
                              _buildFeaturesPreview(data),
                              const SizedBox(height: 10),
                              // ── Edit button ───────────────────────
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showEditPackageDialog(
                                    context,
                                    doc.id,
                                    data,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Edit Package',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Logout Button ─────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesPreview(Map<String, dynamic> data) {
    final features = data['features'] as Map<String, dynamic>? ?? {};
    final orderLimit = features['order_limit'] ?? 0;
    final editNota = features['edit_nota'] ?? false;
    final editWa = features['edit_wa_message'] ?? false;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _featureChip(
          '${orderLimit == 0 ? '∞' : orderLimit} order/bln',
          Icons.shopping_bag_outlined,
          Colors.blue,
        ),
        _featureChip(
          editNota ? 'Edit Nota ✓' : 'Edit Nota ✗',
          Icons.receipt_outlined,
          editNota ? Colors.green : Colors.grey,
        ),
        _featureChip(
          editWa ? 'WA Custom ✓' : 'WA Custom ✗',
          Icons.chat_outlined,
          editWa ? Colors.green : Colors.grey,
        ),
      ],
    );
  }

  Widget _featureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialog Edit Package ───────────────────────────────────────────────
  void _showEditPackageDialog(
    BuildContext context,
    String packageId,
    Map<String, dynamic> data,
  ) {
    final features = data['features'] as Map<String, dynamic>? ?? {};

    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: (data['price'] ?? 0).toString(),
    );
    final descCtrl = TextEditingController(text: data['description'] ?? '');
    final orderLimitCtrl = TextEditingController(
      text: (features['order_limit'] ?? 0).toString(),
    );

    bool editNota = features['edit_nota'] ?? false;
    bool editWa = features['edit_wa_message'] ?? false;
    bool isActive = data['active'] ?? true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Edit ${data['name'] ?? 'Package'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Nama ─────────────────────────────────────────────
                _dialogLabel('Nama Package'),
                _dialogField(nameCtrl, 'Nama package', Icons.label_outline),
                const SizedBox(height: 12),

                // ── Harga ────────────────────────────────────────────
                _dialogLabel('Harga (Rp)'),
                _dialogField(
                  priceCtrl,
                  'Contoh: 20000',
                  Icons.money,
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // ── Deskripsi ─────────────────────────────────────────
                _dialogLabel('Deskripsi'),
                _dialogField(
                  descCtrl,
                  'Deskripsi singkat',
                  Icons.description_outlined,
                ),
                const SizedBox(height: 12),

                // ── Order Limit ───────────────────────────────────────
                _dialogLabel('Order Limit per Bulan (0 = unlimited)'),
                _dialogField(
                  orderLimitCtrl,
                  'Contoh: 35',
                  Icons.shopping_bag_outlined,
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // ── Toggle Features ───────────────────────────────────
                _dialogLabel('Fitur'),
                const SizedBox(height: 6),
                _buildToggleRow(
                  label: 'Edit Nota',
                  subtitle: 'Izinkan user ubah template nota',
                  value: editNota,
                  onChanged: (v) => setDialogState(() => editNota = v),
                ),
                _buildToggleRow(
                  label: 'Custom WA Message',
                  subtitle: 'Izinkan user ubah pesan WhatsApp',
                  value: editWa,
                  onChanged: (v) => setDialogState(() => editWa = v),
                ),
                const Divider(height: 20),

                // ── Status Aktif ──────────────────────────────────────
                _buildToggleRow(
                  label: 'Package Aktif',
                  subtitle: 'Nonaktifkan agar tidak muncul ke user',
                  value: isActive,
                  activeColor: Colors.green,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection('subscription_packages')
                            .doc(packageId)
                            .update({
                              'name': nameCtrl.text.trim(),
                              'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                              'description': descCtrl.text.trim(),
                              'active': isActive,
                              'features': {
                                'order_limit':
                                    int.tryParse(orderLimitCtrl.text.trim()) ??
                                    0,
                                'edit_nota': editNota,
                                'edit_wa_message': editWa,
                              },
                              'updated_at': FieldValue.serverTimestamp(),
                            });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Package berhasil diperbarui!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal update: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    ),
  );

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: keyboard,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
    ),
  );

  Widget _buildToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color activeColor = Colors.blue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: activeColor),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout?'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (ctx.mounted) {
                Navigator.of(
                  ctx,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
