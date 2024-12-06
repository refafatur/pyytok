import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:universal_io/io.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;
  File? _imageFile;
  String? _currentPhotoUrl;
  Uint8List? _imageBytes;

  final List<String> _genderOptions = ['Laki-laki', 'Perempuan'];

  Widget _getProfileImage() {
    if (_imageBytes != null && kIsWeb) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: MemoryImage(_imageBytes!),
      );
    } else if (_imageFile != null && !kIsWeb) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: FileImage(_imageFile!),
      );
    } else if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(_currentPhotoUrl!),
        onBackgroundImageError: (e, s) {
          print('Error loading image: $e');
        },
      );
    }
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey[300],
      child: Icon(
        Icons.person,
        size: 50,
        color: Colors.grey[600],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _imageBytes = result.files.first.bytes;
            _currentPhotoUrl = null; // Reset URL foto lama
          } else {
            _imageFile = File(result.files.single.path!);
            _currentPhotoUrl = null; // Reset URL foto lama
          }
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih gambar')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    try {
      if (_nameController.text.isEmpty ||
          _selectedDate == null ||
          _selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua field harus diisi')),
        );
        return;
      }

      final success = await ApiService.updateProfile(
        _nameController.text,
        kIsWeb ? _imageBytes : _imageFile,
        _selectedDate!,
        _selectedGender!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = await ApiService.getUserProfile();
      if (userData != null && userData['user'] != null) {
        setState(() {
          _nameController.text = userData['user']['nama'] ?? '';
          if (userData['user']['tanggalLahir'] != null) {
            _selectedDate = DateTime.parse(userData['user']['tanggalLahir']);
          }
          _selectedGender = userData['user']['jenisKelamin'];
          _currentPhotoUrl = userData['user']['foto'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat profil: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profil',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('Simpan',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Foto Profil
            Center(
              child: Stack(
                children: [
                  _getProfileImage(),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Form Fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Username
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Tanggal Lahir
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tanggal Lahir',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600])),
                          Text(
                            _selectedDate != null
                                ? DateFormat('dd/MM/yyyy')
                                    .format(_selectedDate!)
                                : 'Pilih Tanggal',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Jenis Kelamin
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Jenis Kelamin'),
                        value: _selectedGender,
                        items: _genderOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedGender = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
