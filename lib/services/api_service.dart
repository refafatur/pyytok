import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Gunakan environment variable atau konfigurasi
const baseUrl = String.fromEnvironment('API_URL', 
  defaultValue: "http://localhost:3000");
const authUrl = "$baseUrl/auth";

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<bool> register(
      String email, 
      String password, 
      String nama, 
      dynamic foto, 
      DateTime tanggalLahir, 
      String jenisKelamin) async {
    try {
      // Validasi input
      if (email.trim().isEmpty || password.trim().isEmpty || nama.trim().isEmpty) {
        throw Exception('Semua field harus diisi');
      }

      var request = http.MultipartRequest('POST', Uri.parse("$authUrl/register"));
      
      // Handle foto dengan lebih baik
      if (foto != null) {
        if (foto is File) {
          request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
        } else if (foto is Uint8List) {
          request.files.add(http.MultipartFile.fromBytes(
            'foto',
            foto,
            filename: 'profile_image.jpg',
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }

      // Tambahkan field lainnya
      request.fields['email'] = email;
      request.fields['password'] = password;
      request.fields['name'] = nama;
      request.fields['tanggalLahir'] = tanggalLahir.toIso8601String();
      request.fields['jenisKelamin'] = jenisKelamin;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data["token"] != null) {
          await saveToken(data["token"]);
          return true;
        }
        throw Exception('Token tidak ditemukan dalam response');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Gagal registrasi');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Tambahkan trim() untuk menghilangkan spasi di awal dan akhir
      email = email.trim();
      
      // Validasi input yang lebih ketat
      if (email.isEmpty || password.trim().isEmpty) {
        throw Exception('Email dan password harus diisi');
      }

      // Validasi format email menggunakan regex
      const emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
      if (!RegExp(emailRegex).hasMatch(email)) {
        throw Exception('Format email tidak valid');
      }
      
      final response = await http.post(
        Uri.parse("$authUrl/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode({
          "email": email,
          "password": password
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data["token"] == null) {
          throw Exception('Token tidak ditemukan dalam response');
        }

        await saveToken(data["token"]);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("email", email);
        
        return {
          "token": data["token"],
          "user": data["user"] ?? {},
          "message": "Login berhasil"
        };
      } else if (response.statusCode == 401) {
        throw Exception('Email atau password salah');
      } else {
        throw Exception('Login gagal: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final token = await getToken();
      
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http.get(
        Uri.parse("$authUrl/user-profile"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Modifikasi URL foto dengan path yang benar
        if (data['user'] != null && data['user']['fotoProfil'] != null) {
          final fotoUrl = data['user']['fotoProfil'];
          if (!fotoUrl.startsWith('http')) {
            data['user']['fotoProfil'] = '$baseUrl/$fotoUrl';
          }
        }
        print('Response data: $data');
        return data;
      } else if (response.statusCode == 401) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove("token");
        throw Exception('Sesi telah berakhir');
      } else {
        throw Exception('Gagal mengambil profil: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error koneksi: $e');
    }
  }

  static Future<bool> updateProfile(
      String nama, 
      dynamic foto, 
      DateTime tanggalLahir, 
      String jenisKelamin) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      var uri = Uri.parse('$baseUrl/auth/edit-profile');
      var request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['nama'] = nama
        ..fields['tanggalLahir'] = tanggalLahir.toIso8601String()
        ..fields['jenisKelamin'] = jenisKelamin;

      if (foto != null) {
        if (foto is Uint8List) {
          // Untuk web
          request.files.add(
            http.MultipartFile.fromBytes(
              'foto',
              foto,
              filename: 'profile_photo.jpg',
              contentType: MediaType('image', 'jpeg'),
            ),
          );
        } else if (foto is File) {
          // Untuk mobile/desktop
          String mimeType = 'image/jpeg';
          String extension = foto.path.split('.').last.toLowerCase();
          
          // Set mime type berdasarkan ekstensi file
          switch (extension) {
            case 'png':
              mimeType = 'image/png';
              break;
            case 'jpg':
            case 'jpeg':
              mimeType = 'image/jpeg';
              break;
            case 'gif':
              mimeType = 'image/gif';
              break;
            case 'webp':
              mimeType = 'image/webp';
              break;
          }

          request.files.add(
            await http.MultipartFile.fromPath(
              'foto',
              foto.path,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Gagal memperbarui profil');
      }
    } catch (e) {
      throw Exception('Gagal memperbarui profil: ${e.toString()}');
    }
  }

  static Future<bool> createPost(String description, dynamic media, String mediaType) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/posts/create"));
      request.headers["Authorization"] = "Bearer $token";
      request.fields['description'] = description;

      if (media != null) {
        String mimeType;
        if (mediaType.toLowerCase().contains('mp4')) {
          mimeType = 'video/mp4';
        } else {
          mimeType = 'image/${mediaType.toLowerCase()}';
        }

        if (kIsWeb && media is Uint8List) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'media',
              media,
              filename: 'post.$mediaType',
              contentType: MediaType.parse(mimeType),
            ),
          );
        } else if (!kIsWeb && media is File) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'media',
              media.path,
              contentType: MediaType.parse(mimeType),
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Gagal membuat postingan');
      }
    } catch (e) {
      print('Error creating post: $e');
      throw Exception('Error: $e');
    }
  }

  static Future<void> logout() async {
    try {
      final token = await getToken();
      
      if (token != null) {
        await http.post(
          Uri.parse("$authUrl/logout"),
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
        );
      }
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove("token");
    } catch (e) {
      throw Exception('Gagal logout: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllPosts() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http.get(
        Uri.parse("$baseUrl/posts"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> posts = List<Map<String, dynamic>>.from(
          data['posts'].map((post) {
            // Modifikasi URL media
            if (post['mediaUrl'] != null && !post['mediaUrl'].startsWith('http')) {
              post['mediaUrl'] = '$baseUrl/${post['mediaUrl']}';
            }
            // Modifikasi URL foto profil
            if (post['user']['foto'] != null && !post['user']['foto'].startsWith('http')) {
              post['user']['foto'] = '$baseUrl/${post['user']['foto']}';
            }
            return post;
          })
        );
        return posts;
      } else {
        throw Exception('Gagal mengambil postingan');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserPosts(String userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      print('Fetching posts for userId: $userId'); // Debug log

      final response = await http.get(
        Uri.parse("$baseUrl/posts/user/$userId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> posts = List<Map<String, dynamic>>.from(
          data['posts'].map((post) {
            if (post['mediaUrl'] != null && !post['mediaUrl'].startsWith('http')) {
              post['mediaUrl'] = '$baseUrl/${post['mediaUrl']}';
            }
            return post;
          })
        );
        return posts;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Gagal mengambil postingan user');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>> likePost(String postId) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.post(
        Uri.parse("$baseUrl/posts/$postId/like"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'isLiked': data['isLiked'],
          'likesCount': data['likesCount']
        };
      } else {
        throw Exception('Gagal memperbarui like');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<bool> checkLikeStatus(String postId) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.get(
        Uri.parse("$baseUrl/posts/$postId/like/status"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isLiked'];
      } else {
        throw Exception('Gagal mengecek status like');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> addComment(String postId, String text) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.post(
        Uri.parse("$baseUrl/posts/$postId/comment"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: json.encode({"text": text}),
      );

      if (response.statusCode != 201) {
        throw Exception('Gagal menambahkan komentar');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.get(
        Uri.parse("$baseUrl/posts/$postId/comments"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['comments'].map((comment) {
          // Pastikan URL foto profil lengkap
          if (comment['user']['foto'] != null && !comment['user']['foto'].startsWith('http')) {
            comment['user']['foto'] = '$baseUrl/${comment['user']['foto']}';
          }
          return comment;
        }));
      } else {
        throw Exception('Gagal mengambil komentar');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http.get(
        Uri.parse("$authUrl/notifications"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notifications = <Map<String, dynamic>>[];
        
        if (data['notifications'] != null) {
          data['notifications'].forEach((notification) {
            notifications.add(Map<String, dynamic>.from(notification));
          });

          // Urutkan notifikasi berdasarkan waktu (terbaru dulu)
          notifications.sort((a, b) =>
              DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
        }
        
        return notifications;
      } else {
        throw Exception('Gagal mengambil notifikasi');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http.post(
        Uri.parse("$authUrl/notifications/$notificationId/read"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Gagal menandai notifikasi sebagai telah dibaca');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<int> getUnreadNotificationsCount() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http.get(
        Uri.parse("$authUrl/notifications/unread/count"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      } else {
        throw Exception('Gagal mengambil jumlah notifikasi yang belum dibaca');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>> getPostDetails(String postId) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('Token tidak ditemukan');

      final response = await http.get(
        Uri.parse("$baseUrl/posts/$postId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Modifikasi URL media dan foto profil jika perlu
        if (data['mediaUrl'] != null && !data['mediaUrl'].startsWith('http')) {
          data['mediaUrl'] = '$baseUrl/${data['mediaUrl']}';
        }
        if (data['user']['foto'] != null && !data['user']['foto'].startsWith('http')) {
          data['user']['foto'] = '$baseUrl/${data['user']['foto']}';
        }
        return data;
      } else {
        throw Exception('Gagal mengambil detail postingan');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
