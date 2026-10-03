import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mdnlaundry_project/core/theme/theme.dart';
import 'package:mdnlaundry_project/features/subscription/payment_page.dart';
import 'package:mdnlaundry_project/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mdnlaundry_project/services/wa_settings_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  WA AUTO SECTION WIDGET — 3 mode: Off / Manual / Otomatis
// ══════════════════════════════════════════════════════════════════════════════
class WaAutoSection extends StatefulWidget {
  const WaAutoSection({super.key});

  @override
  State<WaAutoSection> createState() => _WaAutoSectionState();
}

class _WaAutoSectionState extends State<WaAutoSection> {
  String _mode = 'manual'; // 'off' | 'manual' | 'auto'
  bool _loading = true;
  bool _tokenVisible = false;
  bool _saving = false;
  final _tokenCtrl = TextEditingController();

  static const waGreen = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final mode = await WaSettings.getMode();
    final token = await WaSettings.getToken();
    if (mounted) {
      setState(() {
        _mode = mode;
        _loading = false;
        _tokenCtrl.text = token;
      });
    }
  }

  Future<void> _setMode(String mode) async {
    await WaSettings.setMode(mode);
    setState(() => _mode = mode);
  }

  // ── Toggle utama: nyalakan/matikan notifikasi WA
  Future<void> _toggleActive(bool value) async {
    if (value) {
      // ON → default ke 'manual'
      await _setMode('manual');
    } else {
      // OFF
      await _setMode('off');
    }
  }

  Future<void> _saveToken() async {
    if (_tokenCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await WaSettings.setToken(_tokenCtrl.text.trim());
    if (mounted) {
      setState(() => _saving = false);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Token Fonnte berhasil disimpan'),
            ],
          ),
          backgroundColor: waGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ── Widget pilihan mode (radio card) — kini bisa dikunci ────────────
  Widget _modeOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool enabled, //
  }) {
    final isSelected = _mode == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? () => _setMode(value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: !enabled
              ? (isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100)
              : (isSelected
                    ? color.withOpacity(0.08)
                    : (isDark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.grey.shade50)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: !enabled
                ? Theme.of(context).dividerColor.withOpacity(0.2)
                : (isSelected
                      ? color
                      : Theme.of(context).dividerColor.withOpacity(0.4)),
            width: (enabled && isSelected) ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: enabled
                    ? color.withOpacity(0.12)
                    : Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: enabled ? color : Colors.grey.shade400,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: !enabled
                          ? Colors.grey.shade400
                          : (isSelected
                                ? color
                                : Theme.of(context).textTheme.bodyLarge?.color),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: !enabled
                          ? Colors.grey.shade400
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            // Radio indicator
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: !enabled
                      ? Colors.grey.shade300
                      : (isSelected ? color : Colors.grey.shade400),
                  width: 2,
                ),
                color: (enabled && isSelected) ? color : Colors.transparent,
              ),
              child: (enabled && isSelected)
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final isActive = _mode != 'off'; //

    // Warna & label header sesuai mode aktif
    Color headerColor;
    String headerSubtitle;
    switch (_mode) {
      case 'off':
        headerColor = Colors.grey;
        headerSubtitle = 'Nonaktif – tidak ada notifikasi WA';
        break;
      case 'auto':
        headerColor = waGreen;
        headerSubtitle = 'Otomatis – terkirim langsung via Fonnte';
        break;
      default:
        headerColor = Colors.blue;
        headerSubtitle = 'Manual – buka WA, admin tekan kirim';
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: headerColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: headerColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header dengan toggle utama
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: headerColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.send, color: headerColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifikasi WhatsApp',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headerSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: headerColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isActive,
                    onChanged: _toggleActive,
                    activeColor: waGreen,
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.3),
            ),

            // ── 2 Pilihan mode (Manual / Otomatis)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  _modeOption(
                    value: 'manual',
                    title: 'Manual',
                    subtitle: 'Buka WhatsApp, admin tekan kirim sendiri',
                    icon: Icons.touch_app_outlined,
                    color: Colors.blue,
                    enabled: isActive, //
                  ),
                  _modeOption(
                    value: 'auto',
                    title: 'Otomatis (Fonnte)',
                    subtitle: 'Terkirim langsung tanpa buka WhatsApp',
                    icon: Icons.flash_on_rounded,
                    color: waGreen,
                    enabled: isActive, //
                  ),
                ],
              ),
            ),

            // ── Token Fonnte (hanya tampil saat mode = auto) ────────
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _mode == 'auto'
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: waGreen.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: waGreen.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: waGreen,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
                                        height: 1.5,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: 'Daftarkan nomor WA kamu di ',
                                        ),
                                        TextSpan(
                                          text: 'fonnte.com',
                                          style: TextStyle(
                                            color: waGreen,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              ' lalu salin token dari Dashboard → Token API.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Token Fonnte',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 6),

                          TextField(
                            controller: _tokenCtrl,
                            obscureText: !_tokenVisible,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                              letterSpacing: _tokenVisible ? 0.5 : 2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Paste token Fonnte di sini...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                                letterSpacing: 0,
                                fontFamily: 'sans-serif',
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _tokenVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: Colors.grey.shade400,
                                ),
                                onPressed: () => setState(
                                  () => _tokenVisible = !_tokenVisible,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: waGreen,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _saving || _tokenCtrl.text.trim().isEmpty
                                  ? null
                                  : _saveToken,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined, size: 16),
                              label: Text(
                                _saving ? 'Menyimpan...' : 'Simpan Token',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: waGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WA FOOTER SECTION WIDGET — footer pesan WA, gated oleh paket subscription
// ══════════════════════════════════════════════════════════════════════════════
class WaFooterSection extends StatefulWidget {
  final String storeId; // ← TAMBAHAN: wajib, untuk isFeatureEnabled
  final String outletId; // ← TAMBAHAN: wajib, untuk isFeatureEnabled
  final String outletName;

  const WaFooterSection({
    super.key,
    required this.storeId,
    required this.outletId,
    required this.outletName,
  });

  @override
  State<WaFooterSection> createState() => _WaFooterSectionState();
}

class _WaFooterSectionState extends State<WaFooterSection> {
  final _footerCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _hasAccess = false;
  bool _footerEnabled = true; //

  static const waGreen = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      WaSettings.getFooter(),
      SubscriptionService.isFeatureEnabled(
        storeId: widget.storeId,
        outletId: widget.outletId,
        feature: 'edit_wa_message',
      ),
      WaSettings.isFooterEnabled(), //
    ]);
    if (mounted) {
      setState(() {
        _hasAccess = results[1] as bool;
        _footerEnabled = results[2] as bool; //
        // Tampilkan teks tersimpan di field, terlepas dari status toggle,
        // supaya saat di-ON-kan lagi isinya tidak hilang
        _footerCtrl.text = (results[0] as String).isEmpty
            ? WaSettings.defaultFooter
            : results[0] as String;
        _loading = false;
      });
    }
  }

  // ── Toggle on/off footer
  Future<void> _toggleFooterEnabled(bool value) async {
    if (!_hasAccess) {
      _showUpgradeDialog();
      return;
    }
    setState(() => _footerEnabled = value);
    await WaSettings.setFooterEnabled(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Footer pesan WA diaktifkan'
                : 'Footer pesan WA dinonaktifkan',
          ),
          backgroundColor: value ? waGreen : Colors.grey.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_hasAccess) return;
    setState(() => _saving = true);
    await WaSettings.setFooter(_footerCtrl.text);
    if (mounted) {
      setState(() => _saving = false);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Footer pesan WA berhasil disimpan'),
            ],
          ),
          backgroundColor: waGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _resetDefault() async {
    if (!_hasAccess) return;
    setState(() => _footerCtrl.text = WaSettings.defaultFooter);
    await WaSettings.setFooter('');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Footer dikembalikan ke default'),
          backgroundColor: Colors.blueGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.orange,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Fitur Premium', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: const Text(
          'Custom footer pesan WhatsApp hanya tersedia untuk paket dengan fitur "Custom WA Message". '
          'Upgrade paket outlet Anda untuk mengaktifkan fitur ini.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _goToUpgradePage();
            },
            child: const Text('Upgrade Sekarang'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToUpgradePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionPaymentPage(
          storeId: widget.storeId,
          outletId: widget.outletId,
          outletName: widget.outletName,
          isUpgradeFlow: true,
          onPaymentSuccess: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
    if (mounted) {
      setState(() => _loading = true);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final accentColor = _hasAccess ? waGreen : Colors.grey;
    // Field & tombol disabled juga kalau footer di-OFF, walaupun PRO
    final fieldActive = _hasAccess && _footerEnabled;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.format_quote_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Footer Pesan WhatsApp',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !_hasAccess
                            ? 'Perlu upgrade paket untuk mengubah'
                            : (_footerEnabled
                                  ? 'Baris penutup di setiap pesan WA'
                                  : 'Footer dinonaktifkan'),
                        style: TextStyle(
                          fontSize: 12,
                          color: !_hasAccess
                              ? accentColor
                              : (_footerEnabled
                                    ? accentColor
                                    : Colors.grey.shade500),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Toggle switch
                if (_hasAccess)
                  Switch(
                    value: _footerEnabled,
                    onChanged: _toggleFooterEnabled,
                    activeColor: waGreen,
                  )
                else
                  GestureDetector(
                    onTap: _showUpgradeDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 11,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Upgrade',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.3),
            ),
            const SizedBox(height: 14),

            // ── Input footer ─────────────────────────────────────────
            Row(
              children: [
                Text(
                  'Teks Footer',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                if (!fieldActive) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: fieldActive
                  ? null
                  : (!_hasAccess ? _showUpgradeDialog : null),
              child: AbsorbPointer(
                absorbing: !fieldActive,
                child: TextField(
                  controller: _footerCtrl,
                  enabled: fieldActive,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    color: fieldActive
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : Colors.grey.shade500,
                  ),
                  decoration: InputDecoration(
                    hintText: WaSettings.defaultFooter,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: !fieldActive
                        ? (isDark
                              ? Colors.white.withOpacity(0.02)
                              : Colors.grey.shade100)
                        : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade50),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: waGreen, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              !_hasAccess
                  ? 'Saat ini menggunakan footer default. Upgrade untuk mengubahnya.'
                  : (_footerEnabled
                        ? 'Paket anda sudah PRO silahkan ganti footer pesan WA nya'
                        : 'Footer tidak akan ditampilkan di pesan WA.'),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),

            // ── Preview ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fieldActive
                    ? const Color(0xFFDCF8C6).withOpacity(isDark ? 0.15 : 1)
                    : (isDark
                          ? Colors.white.withOpacity(0.04)
                          : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: fieldActive ? waGreen : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !_footerEnabled
                          ? '(Tidak ada footer — dinonaktifkan)'
                          : (_footerCtrl.text.trim().isEmpty
                                ? WaSettings.defaultFooter
                                : _footerCtrl.text.trim()),
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: fieldActive
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Tombol aksi ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_saving || !fieldActive) ? null : _resetDefault,
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Default'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      disabledForegroundColor: Colors.grey.shade400,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : (fieldActive
                              ? _save
                              : (!_hasAccess ? _showUpgradeDialog : null)),
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            fieldActive
                                ? Icons.save_outlined
                                : Icons.lock_outline_rounded,
                            size: 16,
                          ),
                    label: Text(
                      _saving
                          ? 'Menyimpan...'
                          : (fieldActive ? 'Simpan Footer' : 'Terkunci'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fieldActive
                          ? waGreen
                          : Colors.grey.shade300,
                      foregroundColor: fieldActive
                          ? Colors.white
                          : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
