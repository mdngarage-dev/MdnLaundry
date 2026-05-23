import 'package:flutter/material.dart';
import 'screens.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const OrderScreen(),
    const AddPatientScreen(),
    const LaporanScreen(),
    const SettingScreen(),
  ];

  // ✅ initState di sini — setelah _screens, sebelum build
  @override
  void initState() {
    super.initState();
    // Cek otomatis: jika app tidak dibuka > 24 jam → logout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAutoLogout(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: CustomBottomNav(
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
