import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/login_screen.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'edit_profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  late SharedPreferences _prefs;
  List<Map<String, dynamic>> _userPosts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializePrefs();
    _loadUserPosts();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Coba ambil data dari cache
      final String? cachedProfile = _prefs.getString('user_profile');
      if (cachedProfile != null) {
        setState(() {
          _userProfile = json.decode(cachedProfile);
          _isLoading = false;
        });
      }
      
      // Load dari API
      final profile = await ApiService.getUserProfile();
      
      if (!mounted) return;
      
      if (profile != null) {
        // Simpan ke cache
        await _prefs.setString('user_profile', json.encode(profile));
        
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error loading profile', error: e.toString());
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      // Cek apakah error karena token tidak valid
      if (e.toString().contains('Sesi telah berakhir')) {
        await _handleLogout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await ApiService.logout();
      // Hapus data profile dari SharedPreferences saat logout
      await _prefs.remove('user_profile');
      
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      developer.log('Error logging out', error: e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout gagal: ${e.toString().replaceAll('Exception:', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      if (_userProfile == null || _userProfile!['user'] == null) {
        await _loadUserProfile();
      }

      if (_userProfile != null && _userProfile!['user'] != null) {
        final userId = _userProfile!['user']['id']?.toString();
        
        print('Loading posts for userId: $userId'); // Debug log
        print('User profile data: $_userProfile'); // Debug log
        
        if (userId == null) {
          developer.log('User ID tidak ditemukan dalam profil');
          return;
        }

        final posts = await ApiService.getUserPosts(userId);
        print('Received posts: $posts'); // Debug log
        
        if (!mounted) return;
        
        setState(() {
          _userPosts = posts.map((post) {
            return {
              'createdAt': post['createdAt'],
              'description': post['description'],
              'mediaType': post['mediaType'],
              'mediaUrl': post['mediaUrl'],
              'shares': post['shares'],
              'userId': post['userId'],
            };
          }).toList();
        });
      }
    } catch (e) {
      developer.log('Error loading user posts', error: e.toString());
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat postingan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userProfile?['user']['nama'] ?? '',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold
          )
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserProfile();
          await _loadUserPosts();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _userProfile == null
                ? const Center(child: Text('Data profil tidak tersedia'))
                : Column(
                    children: [
                      // Profile Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                        child: Column(
                          children: [
                            // Profile Picture
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: _userProfile!['user']['foto'] != null && 
                                              _userProfile!['user']['foto'].toString().isNotEmpty
                                ? NetworkImage(_userProfile!['user']['foto'])
                                : null,
                              child: _userProfile!['user']['foto'] == null || 
                                     _userProfile!['user']['foto'].toString().isEmpty
                                ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                                : null,
                            ),
                            const SizedBox(height: 15),
                            
                            // User Info
                            Text('@${_userProfile!['user']['nama']}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                            ),
                            const SizedBox(height: 20),

                            // Stats Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStatColumn('Mengikuti', '0'),
                                const SizedBox(
                                  height: 20,
                                  child: VerticalDivider(color: Colors.grey),
                                ),
                                _buildStatColumn('Pengikut', '0'),
                                const SizedBox(
                                  height: 20,
                                  child: VerticalDivider(color: Colors.grey),
                                ),
                                _buildStatColumn('Suka', '0'),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Edit Profile Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    child: const Text('Edit Profil'),
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const EditProfilePage(),
                                        ),
                                      );
                                      
                                      // Refresh profil jika ada perubahan
                                      if (result == true) {
                                        _loadUserProfile();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Tab Bar
                      TabBar(
                        controller: _tabController,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.black,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on)),
                          Tab(icon: Icon(Icons.favorite_border)),
                        ],
                      ),

                      // Tab Bar View
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Posts Grid
                            _buildPostsGrid(),
                            
                            // Liked Posts Grid (kosong untuk saat ini)
                            Center(
                              child: Text(
                                'Belum ada postingan yang disukai',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleLogout,
        tooltip: 'Logout',
        child: const Icon(Icons.logout),
      ),
    );
  }

  Widget _buildStatColumn(String title, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        children: [
          Text(count,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold
            )
          ),
          Text(title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14
            )
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid() {
    if (_userPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada postingan',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return Image.network(
          post['mediaUrl'],
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return Container(
              color: Colors.grey[300],
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
              ),
            );
          },
        );
      },
    );
  }
}
