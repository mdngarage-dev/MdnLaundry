import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:mdnlaundry_project/core/app_exports.dart';

class CustomBottomNav extends StatefulWidget {
  final Function(int) onTap; // Fungsi kirim index ke luar
  const CustomBottomNav({super.key, required this.onTap});

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  int _pageIndex = 0;
  final Color activeColor = kPrimary;
  final Color inactiveColor = const Color(0xFF616161);

  @override
  Widget build(BuildContext context) {
    return CurvedNavigationBar(
      backgroundColor: Colors.transparent,
      color: Colors.white,
      buttonBackgroundColor: Colors.white,
      height: 65,
      index: _pageIndex,
      animationDuration: const Duration(milliseconds: 300),
      items: _buildNavIcons(),
      onTap: (index) {
        setState(() {
          _pageIndex = index;
        });
        widget.onTap(index); // Jalankan fungsi yang ada di file utama
      },
    );
  }

  List<Widget> _buildNavIcons() {
    return [
      Icon(
        Icons.home_outlined,
        size: 30,
        color: _pageIndex == 0 ? activeColor : inactiveColor,
      ),
      Icon(
        Icons.assignment_outlined,
        size: 30,
        color: _pageIndex == 1 ? activeColor : inactiveColor,
      ),
      Icon(
        Icons.add_circle,
        size: 35,
        color: _pageIndex == 2 ? activeColor : inactiveColor,
      ),
      Icon(
        Icons.bar_chart_outlined,
        size: 30,
        color: _pageIndex == 3 ? activeColor : inactiveColor,
      ),
      Icon(
        Icons.settings_outlined,
        size: 30,
        color: _pageIndex == 4 ? activeColor : inactiveColor,
      ),
    ];
  }
}
