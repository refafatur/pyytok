import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:universal_io/io.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import '../screens/dashboard.dart';

class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  _PostPageState createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final TextEditingController _descriptionController = TextEditingController();
  File? _mediaFile;
  Uint8List? _mediaBytes;
  String? _mediaType;
  bool _isLoading = false;

  Future<void> _pickMedia() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _mediaBytes = result.files.first.bytes;
            _mediaType = result.files.first.extension;
          } else {
            _mediaFile = File(result.files.single.path!);
            _mediaType = result.files.first.extension;
          }
        });
      }
    } catch (e) {
      print('Error picking media: $e');
    }
  }

  Widget _buildMediaPreview() {
    if (_mediaBytes != null && kIsWeb) {
      if (_mediaType?.toLowerCase() == 'mp4') {
        return Container(
          height: 300,
          width: double.infinity,
          color: Colors.grey[300],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_file, size: 50, color: Colors.grey[600]),
                const SizedBox(height: 10),
                Text('Video dipilih: $_mediaType'),
              ],
            ),
          ),
        );
      }
      return Container(
        height: 300,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: MemoryImage(_mediaBytes!),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (_mediaFile != null && !kIsWeb) {
      if (_mediaType?.toLowerCase() == 'mp4') {
        return Container(
          height: 300,
          width: double.infinity,
          color: Colors.grey[300],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_file, size: 50, color: Colors.grey[600]),
                const SizedBox(height: 10),
                const Text('Video dipilih'),
              ],
            ),
          ),
        );
      }
      return SizedBox(
        height: 300,
        width: double.infinity,
        child: Image.file(
          _mediaFile!,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      height: 300,
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 50, color: Colors.grey[600]),
            const SizedBox(height: 10),
            const Text('Tambahkan Foto/Video'),
          ],
        ),
      ),
    );
  }

  void _clearPost() {
    setState(() {
      _descriptionController.clear();
      _mediaFile = null;
      _mediaBytes = null;
      _mediaType = null;
    });
  }

  Future<void> _submitPost() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deskripsi tidak boleh kosong')),
      );
      return;
    }

    if (_mediaFile == null && _mediaBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih foto atau video')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ApiService.createPost(
        _descriptionController.text,
        kIsWeb ? _mediaBytes : _mediaFile,
        _mediaType?.toLowerCase() ?? 'jpg'
      );

      if (success) {
        _clearPost();
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post berhasil dibuat')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Postingan'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text(
                    'Posting',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Media Preview & Picker
            GestureDetector(
              onTap: _pickMedia,
              child: _buildMediaPreview(),
            ),

            // Description Input
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Tulis deskripsi...\n#tambahkan tagar\n@sebut teman',
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            // Additional Options
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Tambah Tagar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement hashtag picker
              },
            ),

            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('Sebut Teman'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement mention picker
              },
            ),
          ],
        ),
      ),
    );
  }
}
