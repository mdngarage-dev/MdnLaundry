import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens.dart';

class ButtonBawah extends StatelessWidget {
  final Map<String, dynamic>? resultData;
  final bool isLoading;
  final VoidCallback onSave;
  final Color accentPurple;
  final String subLayananKIA;

  const ButtonBawah({
    super.key,
    required this.resultData,
    required this.isLoading,
    required this.onSave,
    required this.accentPurple,
    required this.subLayananKIA,
  });

  // ─────────────────────────────────────────────
  // STATIC: Tampilkan bottom sheet pilihan WA
  // ─────────────────────────────────────────────
  static void showWhatsAppOptions(
    BuildContext context,
    Map<String, dynamic> data,
    String subLayanan,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Pilih Aplikasi WhatsApp",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text("WhatsApp Biasa"),
                onTap: () {
                  Navigator.pop(context);
                  _launchWA(data, "biasa", subLayanan);
                },
              ),
              ListTile(
                leading: const Icon(Icons.business, color: Colors.green),
                title: const Text("WhatsApp Business"),
                onTap: () {
                  Navigator.pop(context);
                  _launchWA(data, "bisnis", subLayanan);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // STATIC: Logika kirim pesan WA
  // ─────────────────────────────────────────────
  static Future<void> _launchWA(
    Map<String, dynamic>? data,
    String type,
    String subLayanan,
  ) async {
    if (data == null || (data['hp'] ?? "").toString().isEmpty) {
      debugPrint("Data pasien atau Nomor HP kosong!");
      return;
    }

    String phone = data['hp'].toString();
    int bulanTambah = 1;
    if (subLayanan == "KB 2 Bulan") bulanTambah = 2;
    if (subLayanan == "KB 3 Bulan") bulanTambah = 3;

    DateTime now = DateTime.now();
    DateTime tglKembaliRaw = DateTime(
      now.year,
      now.month + bulanTambah,
      now.day,
    ).subtract(const Duration(days: 3));

    String tglKembali =
        "${tglKembaliRaw.day.toString().padLeft(2, '0')}-${tglKembaliRaw.month.toString().padLeft(2, '0')}-${tglKembaliRaw.year}";

    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('8')) {
      cleanPhone = '62$cleanPhone';
    } else if (!cleanPhone.startsWith('62')) {
      cleanPhone = '62$cleanPhone';
    }

    String message = "";
    String layanan = (data['layan'] ?? "").toString().toUpperCase();

    if (layanan == "KIA") {
      message =
          """Halo Bunda *${data['nama']}*, 👋

Terima kasih telah mempercayakan pemeriksaan di *${OutletSettings.namaKlinik}*. Berikut ringkasannya:

🆔 *NIP:* ${data['nip']}
👶 *Layanan:* KB 
⚖️ *Berat:* ${data['berat']} kg
📝 *Catatan:* ${data['keluhan']}
🗓️ *Jadwal Kontrol Berikutnya:* *Tanggal: $tglKembali* (Estimasi)

Sehat selalu,! 😊""";
    } else {
      message =
          """Halo *${data['nama']}*, 👋

Terima kasih telah melakukan pemeriksaan di *${OutletSettings.namaKlinik}*. Berikut ringkasan kunjungan Anda:

🆔 *NIP:* ${data['nip']}
🏥 *Layanan:* ${data['layan']}
⚖️ *Berat:* ${data['berat']} kg
📝 *Keluhan:* ${data['keluhan']}

Semoga lekas sembuh dan sehat selalu. Salam hangat. 😊""";
    }

    String encodedMsg = Uri.encodeComponent(message);

    // FIX: Untuk WA Business gunakan skema 'whatsapp-biz://' jika tersedia,
    // fallback ke wa.me jika gagal
    Uri url;
    if (type == "bisnis") {
      url = Uri.parse("whatsapp://send?phone=$cleanPhone&text=$encodedMsg");
    } else {
      url = Uri.parse("whatsapp://send?phone=$cleanPhone&text=$encodedMsg");
    }

    try {
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback ke wa.me jika skema whatsapp:// gagal
        await launchUrl(
          Uri.parse("https://wa.me/$cleanPhone?text=$encodedMsg"),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint("Error Launching WA: $e");
      // Fallback terakhir via browser
      try {
        await launchUrl(
          Uri.parse("https://wa.me/$cleanPhone?text=$encodedMsg"),
          mode: LaunchMode.externalApplication,
        );
      } catch (e2) {
        debugPrint("Fallback WA juga gagal: $e2");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // TOMBOL WHATSAPP
            // FIX: Gunakan showWhatsAppOptions (static) bukan _showWhatsAppOptions (tidak ada)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (resultData == null)
                    ? null
                    : () => showWhatsAppOptions(
                        context,
                        resultData!,
                        subLayananKIA, // FIX: Teruskan subLayananKIA dari property widget
                      ),
                icon: const Icon(Icons.share, size: 20),
                label: const Text("WHATSAPP"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        // TOMBOL SIMPAN
        ElevatedButton(
          onPressed: (isLoading || resultData == null) ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentPurple,
            disabledBackgroundColor: Colors.grey,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
                  "SIMPAN KUNJUNGAN BARU",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ],
    );
  }
}
