import 'package:flutter/material.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';

class PrinterDialog {
  static void show(BuildContext context, Map<String, dynamic> data) async {
    ThermalPrinterService printerService = ThermalPrinterService();
    List<BluetoothDevice> devices = await printerService.getPairedDevices();

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
                "Pilih Printer Thermal",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              devices.isEmpty
                  ? const Text("Tidak ada printer dipairing")
                  : SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          return Material(
                            color: Colors.transparent, // ← TAMBAH
                            child: ListTile(
                              leading: const Icon(Icons.print),
                              title: Text(devices[index].name ?? "Unknown"),
                              subtitle: Text(devices[index].address ?? ""),
                              onTap: () {
                                Navigator.pop(context);
                                printerService.printStruk(devices[index], data);
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}
