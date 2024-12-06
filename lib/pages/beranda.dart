import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  Map<String, bool> _likedPosts = {};
  Map<String, int> _likesCount = {};

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo(String videoUrl) async {
    if (_videoController != null) {
      await _videoController!.dispose();
    }

    try {
      _videoController = VideoPlayerController.network(videoUrl);
      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _videoController!.play();
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
      setState(() {
        _isVideoInitialized = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await ApiService.getAllPosts();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
      
      // Initialize first video if exists
      if (_posts.isNotEmpty && _posts[0]['mediaType'] == 'video') {
        _initializeVideo(_posts[0]['mediaUrl']);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadLikeStatus(String postId) async {
    try {
      final isLiked = await ApiService.checkLikeStatus(postId);
      setState(() {
        _likedPosts[postId] = isLiked;
      });
    } catch (e) {
      print('Error loading like status: $e');
    }
  }

  Widget _buildMediaWidget(Map<String, dynamic> post) {
    if (post['mediaType'] == 'image') {
      return CachedNetworkImage(
        imageUrl: post['mediaUrl'],
        fit: BoxFit.cover,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    } else {
      // Video player
      if (!_isVideoInitialized) {
        return const Center(child: CircularProgressIndicator());
      }

      return GestureDetector(
        onTap: () {
          setState(() {
            if (_videoController!.value.isPlaying) {
              _videoController!.pause();
            } else {
              _videoController!.play();
            }
          });
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
            if (!_videoController!.value.isPlaying)
              Icon(
                Icons.play_arrow,
                size: 60,
                color: Colors.white.withOpacity(0.7),
              ),
          ],
        ),
      );
    }
  }

  Future<void> _showCommentsDialog(String postId) async {
    List<Map<String, dynamic>> comments = [];
    bool isLoading = true;
    final TextEditingController commentController = TextEditingController();

    try {
      comments = await ApiService.getComments(postId);
      isLoading = false;
    } catch (e) {
      print('Error loading comments: $e');
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Komentar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Daftar Komentar
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(
                                comment['user']['foto'] ?? '',
                              ),
                            ),
                            title: Text(comment['user']['name'] ?? ''),
                            subtitle: Text(comment['text'] ?? ''),
                            trailing: Text(
                              _formatTimestamp(comment['createdAt']),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Input Komentar Baru
              Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 8,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          hintText: 'Tambahkan komentar...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        if (commentController.text.trim().isNotEmpty) {
                          try {
                            await ApiService.addComment(
                              postId,
                              commentController.text.trim(),
                            );
                            commentController.clear();
                            
                            // Refresh komentar
                            setState(() {
                              isLoading = true;
                            });
                            final newComments = await ApiService.getComments(postId);
                            setState(() {
                              comments = newComments;
                              isLoading = false;
                            });
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    final date = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}h yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}j yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m yang lalu';
    } else {
      return 'Baru saja';
    }
  }

  Widget _buildLikeButton(Map<String, dynamic> post) {
    final postId = post['id'];
    final isLiked = _likedPosts[postId] ?? false;
    final likesCount = _likesCount[postId] ?? post['likesCount'] ?? 0;

    return Column(
      children: [
        IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : Colors.white,
          ),
          onPressed: () async {
            try {
              final result = await ApiService.likePost(postId);
              setState(() {
                _likedPosts[postId] = result['isLiked'];
                _likesCount[postId] = result['likesCount'];
              });
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          },
        ),
        Text(
          '$likesCount',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Video Feed
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _posts.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                // Initialize video for new page if it's a video
                if (_posts[index]['mediaType'] == 'video') {
                  _initializeVideo(_posts[index]['mediaUrl']);
                } else {
                  // Pause and dispose video controller if switching to image
                  _videoController?.pause();
                }
              });
            },
            itemBuilder: (context, index) {
              final post = _posts[index];
              return Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    // Media postingan (gambar/video)
                    Center(
                      child: _buildMediaWidget(post),
                    ),
                    
                    // Deskripsi postingan
                    Positioned(
                      bottom: 80,
                      left: 10,
                      right: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${post['user']['name']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post['description'] ?? '',
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Overlay buttons
          Positioned(
            right: 10,
            bottom: 100,
            child: Column(
              children: [
                // User profile image
                CircleAvatar(
                  radius: 25,
                  backgroundImage: CachedNetworkImageProvider(
                    _posts[_currentIndex]['user']['foto'],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Like button
                _buildLikeButton(_posts[_currentIndex]),
                
                // Comment button
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.comment, color: Colors.white),
                      onPressed: () => _showCommentsDialog(_posts[_currentIndex]['id']),
                    ),
                    Text(
                      '${_posts[_currentIndex]['commentsCount']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                
                // Share button
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () {},
                    ),
                    const Text(
                      'Bagikan',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
