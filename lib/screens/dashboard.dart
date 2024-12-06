import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../pages/beranda.dart';
import '../pages/toko.dart';
import '../pages/post.dart';
import '../pages/kotakmasuk.dart';
import '../pages/profile.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _showFloatingNavBar = true;

  final List<Widget> _pages = [
    const BerandaPage(),
    const TokoPage(), 
    const PostPage(),
    const KotakMasukPage(),
    const ProfilePage()
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showFloatingNavBar) {
          setState(() {
            _showFloatingNavBar = false;
          });
        }
      }
      if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showFloatingNavBar) {
          setState(() {
            _showFloatingNavBar = true;
          });
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[100]!, Colors.white, Colors.purple[50]!],
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.2, 0.0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _pages[_selectedIndex],
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _showFloatingNavBar ? 20 : -80,
            left: 20,
            right: 20,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCenterNavItem(0, Icons.home_rounded, 'Beranda', Colors.blue),
                  _buildCenterNavItem(1, Icons.store_rounded, 'Toko', Colors.blue),
                  _buildCenterNavItem(2, Icons.add_box_rounded, 'Post', Colors.blue),
                  _buildCenterNavItem(3, Icons.mail_rounded, 'Kotak Masuk', Colors.blue),
                  _buildCenterNavItem(4, Icons.person_rounded, 'Profil', Colors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.blue[600] : Colors.grey,
              size: 24,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue[600] : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterNavItem(int index, IconData icon, String label, MaterialColor color) {
    bool isSelected = _selectedIndex == index;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected ? [color[400]!, color[600]!] : [Colors.grey[300]!, Colors.grey[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isSelected ? color : Colors.grey).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 30),
        onPressed: () => _onItemTapped(index),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
