import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class KotakMasukPage extends StatefulWidget {
  const KotakMasukPage({super.key});

  @override
  _KotakMasukPageState createState() => _KotakMasukPageState();
}

class _KotakMasukPageState extends State<KotakMasukPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
    
    // Refresh notifikasi setiap 30 detik
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await ApiService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    String message = '';
    IconData icon;
    Color iconColor;

    switch (notification['type']) {
      case 'like':
        message = '${notification['fromUserName']} menyukai postingan Anda';
        icon = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        message = '${notification['fromUserName']} mengomentari postingan Anda';
        icon = Icons.comment;
        iconColor = Colors.blue;
        break;
      default:
        message = 'Notifikasi baru';
        icon = Icons.notifications;
        iconColor = Colors.grey;
    }

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(
              notification['fromUserPhoto'] ?? 'https://via.placeholder.com/50',
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        message,
        style: TextStyle(
          fontWeight: notification['isRead'] ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(notification['timeAgo'] ?? ''),
      trailing: notification['isRead']
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
      onTap: () async {
        if (!notification['isRead']) {
          try {
            await ApiService.markNotificationAsRead(notification['id']);
            _loadNotifications();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
        // TODO: Navigasi ke post yang terkait
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kotak Masuk',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: 'Semua Aktivitas'),
            Tab(text: 'Pesan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Semua Aktivitas
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: _notifications.isEmpty
                      ? const Center(
                          child: Text('Belum ada notifikasi'),
                        )
                      : ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationItem(_notifications[index]);
                          },
                        ),
                ),
          // Tab Pesan
          ListView.builder(
            itemCount: 15, // Contoh data
            itemBuilder: (context, index) {
              return ListTile(
                leading: Stack(
                  children: [
                    const CircleAvatar(
                      backgroundImage: NetworkImage('https://picsum.photos/50/50'),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                title: const Text(
                  'Perusahaan XYZ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Halo, kami tertarik dengan profil Anda...'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '12:30',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '1',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
