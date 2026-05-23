import 'package:flutter/material.dart';
import 'screens.dart';

class PrintScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const PrintScreen({super.key, required this.data});

  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  final ThermalPrinterService _printerService = ThermalPrinterService();
  List<BluetoothDevice> _devices = [];
  bool _isBluetoothOn = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),

      body: Column(
        children: [
          // Card Info Cara Print
          _buildInfoCard(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.bluetooth, color: kPrimary),
                SizedBox(width: 10),
                Text(
                  "Pilih Printer",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),

          Expanded(
            child: !_isBluetoothOn
                ? _buildBluetoothOffWarning() // Tampilan jika BT Mati
                : _buildDeviceList(), // Tampilan jika BT Nyala
          ),

          // Tombol Refresh
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton.icon(
              onPressed: _checkAndGetDevices,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh Daftar Printer"),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Cara Print",
            style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary),
          ),
          SizedBox(height: 10),
          Text(
            "1. Nyalakan printer Bluetooth\n2. Pair printer dari Settings -> Bluetooth HP\n3. Pilih printer dari daftar di bawah\n4. Tekan 'Connect' untuk mencetak",
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
            "Bluetooth Belum Aktif",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text("Mohon aktifkan Bluetooth untuk mencari printer"),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return const Center(child: Text("Tidak ada printer yang ter-pairing"));
    }
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: kPrimary,
              child: Icon(Icons.print, color: Colors.white),
            ),
            title: Text(_devices[index].name ?? "Unknown"),
            subtitle: Text(_devices[index].address ?? ""),
            trailing: ElevatedButton(
              onPressed: () =>
                  _printerService.printStruk(_devices[index], widget.data),
              child: const Text("Connect"),
            ),
          ),
        );
      },
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
            'Struk Customer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: kPrimary,
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
