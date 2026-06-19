import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import 'package:image_picker/image_picker.dart';
import 'main_screens.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as ml;

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  // Pakai prefix ms. karena ini punya mobile_scanner
  final ms.MobileScannerController controller = ms.MobileScannerController(
    detectionSpeed: ms.DetectionSpeed.noDuplicates,
  );

  bool isDetected = false;

  Future<void> _processGalleryImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final inputImage = ml.InputImage.fromFilePath(image.path);
    // Pakai prefix ml. karena ini punya ML Kit
    final ml.BarcodeScanner barcodeScanner = ml.BarcodeScanner();

    try {
      // Sini fix-nya: List<ml.Barcode>
      final List<ml.Barcode> barcodes = await barcodeScanner.processImage(
        inputImage,
      );

      if (barcodes.isNotEmpty && mounted) {
        final String? code = barcodes.first.rawValue;
        if (code != null) {
          isDetected = true;
          Navigator.pop(context, code);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code tidak ditemukan di foto ini'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error Gallery: $e");
    } finally {
      barcodeScanner.close();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),

      body: ms.MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (isDetected) return;

          // Sini pakai prefix ms.
          final List<ms.Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              isDetected = true;
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _processGalleryImage,
        child: const Icon(Icons.image),
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
            'Scan QR Order',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.flash_on, color: kWhite),
              onPressed: () => controller.toggleTorch(),
            ),
          ],
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
