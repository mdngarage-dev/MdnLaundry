import 'package:flutter/material.dart';
import 'main_screens.dart';

class PrintScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String jenisCetak; // 'customer' atau 'produksi'

  const PrintScreen({
    super.key,
    required this.data,
    this.jenisCetak = 'customer', // default customer
  });

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  final ThermalPrinterService _printerService = ThermalPrinterService();
  List<BluetoothDevice> _devices = [];
  bool _isBluetoothOn = false;
  bool _isPrinting = false;

  bool get _isProduksi => widget.jenisCetak == 'produksi';

  @override
  void initState() {
    super.initState();
    _checkAndGetDevices();
  }

  Future<void> _checkAndGetDevices() async {
    bool isOn = await _printerService.isBluetoothOn();
    setState(() => _isBluetoothOn = isOn);
    if (isOn) {
      List<BluetoothDevice> paired = await _printerService.getPairedDevices();
      setState(() => _devices = paired);
    }
  }

  Future<void> _onPrint(BluetoothDevice device) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      // ← Arahkan ke method yang sesuai
      if (_isProduksi) {
        await _printerService.printStrukProduksi(device, widget.data);
      } else {
        await _printerService.printStruk(device, widget.data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isProduksi
                  ? 'Struk produksi berhasil dicetak'
                  : 'Struk customer berhasil dicetak',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal cetak: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildInfoCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: _isProduksi ? Colors.orange.shade700 : kPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Pilih Printer',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: !_isBluetoothOn
                ? _buildBluetoothOffWarning()
                : _buildDeviceList(),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton.icon(
              onPressed: _checkAndGetDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Daftar Printer'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara Print',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _isProduksi ? Colors.orange.shade700 : kPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '1. Nyalakan printer Bluetooth\n'
            '2. Pair printer dari Settings → Bluetooth HP\n'
            '3. Pilih printer dari daftar di bawah\n'
            '4. Tekan \'Connect\' untuk mencetak',
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothOffWarning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            'Bluetooth Belum Aktif',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text('Mohon aktifkan Bluetooth untuk mencari printer'),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return const Center(child: Text('Tidak ada printer yang ter-pairing'));
    }
    final activeColor = _isProduksi ? Colors.orange.shade700 : kPrimary;
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: activeColor,
              child: const Icon(Icons.print, color: Colors.white),
            ),
            title: Text(device.name ?? 'Unknown'),
            subtitle: Text(device.address ?? ''),
            trailing: _isPrinting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: activeColor,
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => _onPrint(device),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Connect'),
                  ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final activeColor = _isProduksi ? Colors.orange.shade700 : kPrimary;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: AppBar(
          title: Text(
            _isProduksi ? 'Struk Produksi' : 'Struk Customer',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: activeColor,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
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
