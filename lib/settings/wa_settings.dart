import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  WA SETTINGS HELPER — pakai mode: 'off' | 'manual' | 'auto'
// ══════════════════════════════════════════════════════════════════════════════
class WaSettings {
  static const _keyMode = 'wa_mode';
  static const _keyToken = 'wa_fonnte_token';

  static Future<String> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMode) ?? 'manual'; // default: manual
  }

  static Future<void> setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode);
  }

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken) ?? '';
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  // ── Helper untuk dipanggil dari add_order_screen.dart ─────────────
  static Future<bool> isOff() async => (await getMode()) == 'off';
  static Future<bool> isManual() async => (await getMode()) == 'manual';
  static Future<bool> isAuto() async => (await getMode()) == 'auto';
}

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

  void _showPreviewPesan() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.send, color: waGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Contoh Pesan WA',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pesan yang dikirim ke pelanggan',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF8C6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Halo, *Ibu Ameena* 👋\n\n'
                'Terima kasih telah mempercayakan laundry Anda! '
                'Pesanan telah kami terima.\n\n'
                '📋 *Detail Order:*\n'
                '• No. Order       : *MDN260611028*\n'
                '• Layanan          : Setrika Reguler\n'
                '• Total               : *Rp 46.000*\n'
                '• Pembayaran   : ⏳ Bayar saat ambil\n'
                '• Est. Selesai     : 14-06-2026\n\n'
                '🔍 *Lacak status order Anda:*\n'
                'https://laundry-ku-id.web.app/MDN260611028\n\n'
                'Kami segera memproses laundry Anda. Terima kasih! 🙏\n\n'
                '_Madeena Laundry_',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget pilihan mode (radio card) ──────────────────────────────
  Widget _modeOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _mode == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _setMode(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.08)
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).dividerColor.withOpacity(0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
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
                      color: isSelected
                          ? color
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
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
                  color: isSelected ? color : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
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
            // ── Header ───────────────────────────────────────────────
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
                ],
              ),
            ),

            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.3),
            ),

            // ── 3 Pilihan mode ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  _modeOption(
                    value: 'off',
                    title: 'Nonaktif',
                    subtitle: 'Tidak ada notifikasi WA sama sekali',
                    icon: Icons.notifications_off_outlined,
                    color: Colors.grey,
                  ),
                  _modeOption(
                    value: 'manual',
                    title: 'Manual',
                    subtitle: 'Buka WhatsApp, admin tekan kirim sendiri',
                    icon: Icons.touch_app_outlined,
                    color: Colors.blue,
                  ),
                  _modeOption(
                    value: 'auto',
                    title: 'Otomatis (Fonnte)',
                    subtitle: 'Terkirim langsung tanpa buka WhatsApp',
                    icon: Icons.flash_on_rounded,
                    color: waGreen,
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

            // ── Preview pesan (tampil untuk manual & auto, bukan off) ─
            if (_mode != 'off') ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
              ),
              InkWell(
                onTap: _showPreviewPesan,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.preview_outlined,
                          color: Theme.of(context).primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lihat Contoh Pesan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            Text(
                              'Preview pesan WA ke pelanggan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).hintColor,
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
