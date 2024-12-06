import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import db from "../config/firebaseConfig.js";
import { ref, get, push, set, query, orderByChild, equalTo, update } from "firebase/database";
import multer from 'multer';
import path from 'path';
import dotenv from 'dotenv';

// Pastikan dotenv dikonfigurasi di awal file
dotenv.config();

// Ambil SECRET_KEY dari environment variable dan berikan nilai default
const SECRET_KEY = process.env.SECRET_KEY || "fd03fefcf4174ffef90805accb3e01aa63397a476fbc0c3794fc8e6ab9792898";

// Pastikan SECRET_KEY ada
if (!SECRET_KEY) {
  throw new Error('SECRET_KEY tidak ditemukan di environment variables');
}

export const register = async (req, res) => {
  try {
    const { email, password, name, tanggalLahir, jenisKelamin } = req.body;
    const foto = req.file;

    // Validasi input
    if (!email || !password || !name || !tanggalLahir || !jenisKelamin) {
      return res.status(400).json({ message: "Semua field harus diisi" });
    }

    if (!foto) {
      return res.status(400).json({ message: "Foto profil harus diunggah" });
    }

    // Validasi format email
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ message: "Format email tidak valid" });
    }

    // Cek email yang sudah terdaftar
    const usersRef = ref(db, 'users');
    const emailQuery = query(usersRef, orderByChild('email'), equalTo(email));
    const snapshot = await get(emailQuery);
    
    if (snapshot.exists()) {
      return res.status(400).json({ message: "Email sudah terdaftar" });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Tambahkan URL lengkap untuk foto profil
    const fotoUrl = `uploads/profil/${foto.filename}`;

    // Simpan user dengan URL foto yang benar
    const newUserRef = push(usersRef);
    await set(newUserRef, {
      email,
      password: hashedPassword,
      name,
      tanggalLahir,
      jenisKelamin,
      fotoProfil: fotoUrl,
      createdAt: new Date().toISOString()
    });

    // Generate token
    const token = jwt.sign(
      { userId: newUserRef.key, email },
      SECRET_KEY,
      { expiresIn: '1h' }
    );

    res.status(201).json({
      message: "Registrasi berhasil",
      token,
      user: {
        id: newUserRef.key,
        email,
        name,
        tanggalLahir,
        jenisKelamin,
        fotoProfil: fotoUrl
      }
    });

  } catch (error) {
    console.error("Error registrasi:", error);
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Cari user berdasarkan email
    const usersRef = ref(db, 'users');
    const emailQuery = query(usersRef, orderByChild('email'), equalTo(email));
    const snapshot = await get(emailQuery);

    if (!snapshot.exists()) {
      return res.status(400).json({ message: "Email atau password salah" });
    }

    // Ambil data user
    const userData = Object.entries(snapshot.val())[0];
    const userId = userData[0];
    const user = userData[1];

    // Verifikasi password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(400).json({ message: "Email atau password salah" });
    }

    // Generate token
    const token = jwt.sign(
      { userId, email: user.email },
      SECRET_KEY,
      { expiresIn: '24h' }
    );

    res.json({
      message: "Login berhasil",
      token,
      user: {
        id: userId,
        email: user.email,
        name: user.name,
        tanggalLahir: user.tanggalLahir,
        jenisKelamin: user.jenisKelamin,
        fotoProfil: user.fotoProfil
      }
    });

  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const userProfile = async (req, res) => {
  try {
    const userId = req.user.userId;
    console.log('Fetching profile for userId:', userId); // Debug log
    
    const userRef = ref(db, `users/${userId}`);
    const snapshot = await get(userRef);
    
    if (!snapshot.exists()) {
      return res.status(404).json({
        message: "User tidak ditemukan"
      });
    }

    const userData = snapshot.val();
    console.log('User data:', userData); // Debug log
    
    // Pastikan URL foto lengkap
    const foto = userData.fotoProfil ? 
      (userData.fotoProfil.startsWith('http') ? 
        userData.fotoProfil : 
        `${process.env.BASE_URL}/${userData.fotoProfil}`) 
      : null;
    
    res.status(200).json({
      user: {
        id: userId,
        email: userData.email,
        nama: userData.name,
        tanggalLahir: userData.tanggalLahir,
        jenisKelamin: userData.jenisKelamin,
        foto: foto  // Menggunakan key 'foto' yang konsisten
      }
    });
    
  } catch (error) {
    console.error("Error mengambil profil:", error);
    res.status(500).json({
      message: "Terjadi kesalahan server",
      error: error.message
    });
  }
};

export const editProfile = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { nama, tanggalLahir, jenisKelamin } = req.body;
    
    // Validasi input
    if (!nama || !tanggalLahir || !jenisKelamin) {
      return res.status(400).json({ 
        message: "Semua field harus diisi" 
      });
    }

    const userRef = ref(db, `users/${userId}`);
    const snapshot = await get(userRef);

    if (!snapshot.exists()) {
      return res.status(404).json({ 
        message: "User tidak ditemukan" 
      });
    }

    const updateData = {
      name: nama,
      tanggalLahir,
      jenisKelamin,
    };

    // Jika ada foto baru yang diupload
    if (req.file) {
      updateData.fotoProfil = `uploads/profil/${req.file.filename}`;
    }

    // Update user di database
    await update(userRef, updateData);

    res.json({
      success: true,
      message: 'Profil berhasil diperbarui',
      data: updateData
    });
    
  } catch (error) {
    console.error("Error updating profile:", error);
    res.status(500).json({
      success: false,
      message: error.message || 'Terjadi kesalahan saat memperbarui profil'
    });
  }
};

export const createPost = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { description } = req.body;
    const media = req.file;

    console.log('Creating post with userId:', userId); // Debug log
    console.log('Request body:', req.body); // Debug log
    console.log('Uploaded media:', media); // Debug log

    // Validasi input
    if (!description?.trim()) {
      return res.status(400).json({ message: "Deskripsi tidak boleh kosong" });
    }

    if (!media) {
      return res.status(400).json({ message: "Media harus diunggah" });
    }

    const postsRef = ref(db, 'posts');
    const newPostRef = push(postsRef);
    
    // Tentukan tipe media berdasarkan mimetype
    const mediaType = media.mimetype.startsWith('image/') ? 'image' : 'video';
    
    const postData = {
      userId,
      description: description.trim(),
      mediaUrl: `uploads/postingan/${media.filename}`,
      mediaType,
      createdAt: new Date().toISOString(),
      likes: {},
      comments: {},
      shares: 0
    };

    console.log('Saving post data:', postData); // Debug log

    await set(newPostRef, postData);

    console.log('Post saved with ID:', newPostRef.key); // Debug log

    res.status(201).json({
      message: "Post berhasil dibuat",
      post: {
        id: newPostRef.key,
        ...postData
      }
    });

  } catch (error) {
    console.error("Error membuat post:", error);
    res.status(500).json({ 
      message: "Terjadi kesalahan server", 
      error: error.message 
    });
  }
};

export const addNotification = async (toUserId, fromUserId, type, postId) => {
  try {
    const notificationsRef = ref(db, `notifications/${toUserId}`);
    const newNotificationRef = push(notificationsRef);
    
    // Dapatkan informasi user yang melakukan aksi
    const userRef = ref(db, `users/${fromUserId}`);
    const userSnapshot = await get(userRef);
    const userData = userSnapshot.val();

    // Dapatkan informasi post
    const postRef = ref(db, `posts/${postId}`);
    const postSnapshot = await get(postRef);
    const postData = postSnapshot.val();

    const notificationData = {
      type,
      postId,
      fromUserId,
      fromUserName: userData.name,
      fromUserPhoto: userData.fotoProfil,
      postDescription: postData.description,
      postMedia: postData.mediaUrl,
      createdAt: new Date().toISOString(),
      isRead: false
    };

    await set(newNotificationRef, notificationData);
  } catch (error) {
    console.error('Error adding notification:', error);
  }
};

export const likePost = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { postId } = req.params;
    
    const postRef = ref(db, `posts/${postId}`);
    const snapshot = await get(postRef);
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: "Post tidak ditemukan" });
    }

    const post = snapshot.val();
    const likesRef = ref(db, `posts/${postId}/likes`);
    const likesSnapshot = await get(likesRef);
    const likes = likesSnapshot.val() || {};
    
    let isLiked = false;
    
    if (likes[userId]) {
      delete likes[userId];
    } else {
      likes[userId] = {
        timestamp: new Date().toISOString()
      };
      isLiked = true;
      
      // Tambahkan notifikasi hanya jika user menyukai post
      if (post.userId !== userId) { // Jangan kirim notifikasi ke diri sendiri
        await addNotification(post.userId, userId, 'like', postId);
      }
    }
    
    await set(likesRef, likes);
    
    res.json({
      isLiked,
      likesCount: Object.keys(likes).length
    });
    
  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const addComment = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { postId } = req.params;
    const { text } = req.body;
    
    if (!text?.trim()) {
      return res.status(400).json({ message: "Komentar tidak boleh kosong" });
    }

    const postRef = ref(db, `posts/${postId}`);
    const postSnapshot = await get(postRef);
    
    if (!postSnapshot.exists()) {
      return res.status(404).json({ message: "Post tidak ditemukan" });
    }

    const post = postSnapshot.val();
    const commentsRef = ref(db, `posts/${postId}/comments`);
    const newCommentRef = push(commentsRef);
    
    const commentData = {
      userId,
      text: text.trim(),
      createdAt: new Date().toISOString()
    };
    
    await set(newCommentRef, commentData);

    // Tambahkan notifikasi jika komentar bukan dari pemilik post
    if (post.userId !== userId) {
      await addNotification(post.userId, userId, 'comment', postId);
    }

    res.status(201).json({
      message: "Komentar berhasil ditambahkan",
      comment: {
        id: newCommentRef.key,
        ...commentData
      }
    });
    
  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const sharePost = async (req, res) => {
  try {
    const { postId } = req.params;
    
    const postRef = ref(db, `posts/${postId}`);
    const snapshot = await get(postRef);
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: "Post tidak ditemukan" });
    }
    
    const post = snapshot.val();
    const currentShares = post.shares || 0;
    
    await update(postRef, {
      shares: currentShares + 1
    });
    
    res.json({ message: "Share berhasil ditambahkan" });
  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const logout = async (req, res) => {
  try {
    // Di sini bisa ditambahkan logika untuk invalidate token jika diperlukan
    res.status(200).json({ message: "Berhasil logout" });
  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan saat logout" });
  }
};

export const getAllPosts = async (req, res) => {
  try {
    const postsRef = ref(db, 'posts');
    const snapshot = await get(postsRef);
    
    if (!snapshot.exists()) {
      return res.json({ posts: [] });
    }

    const posts = [];
    const postsData = snapshot.val();

    for (const [postId, post] of Object.entries(postsData)) {
      // Ambil data user untuk setiap post
      const userRef = ref(db, `users/${post.userId}`);
      const userSnapshot = await get(userRef);
      const userData = userSnapshot.val();

      posts.push({
        id: postId,
        ...post,
        user: {
          name: userData?.name,
          foto: userData?.fotoProfil
        },
        likesCount: post.likes ? Object.keys(post.likes).length : 0,
        commentsCount: post.comments ? Object.keys(post.comments).length : 0
      });
    }

    posts.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    res.json({ posts });
  } catch (error) {
    console.error("Error mengambil posts:", error);
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const getUserPosts = async (req, res) => {
  try {
    const { userId } = req.params;
    console.log('Fetching posts for userId:', userId); // Debug log
    
    const postsRef = ref(db, 'posts');
    const snapshot = await get(postsRef);
    
    if (!snapshot.exists()) {
      console.log('Tidak ada data posts sama sekali'); // Debug log
      return res.json({ posts: [] });
    }

    const posts = [];
    const postsData = snapshot.val();
    console.log('Data posts yang ditemukan:', postsData); // Debug log

    // Filter posts berdasarkan userId
    for (const [postId, post] of Object.entries(postsData)) {
      if (post.userId === userId) {
        console.log('Match found for post:', postId); // Debug log
        posts.push({
          id: postId,
          createdAt: post.createdAt,
          description: post.description,
          mediaType: post.mediaType,
          mediaUrl: `${process.env.BASE_URL}/${post.mediaUrl}`, // Tambahkan BASE_URL
          shares: post.shares || 0,
          userId: post.userId
        });
      }
    }

    console.log('Final filtered posts:', posts); // Debug log
    
    // Urutkan berdasarkan waktu pembuatan (terbaru dulu)
    posts.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    
    res.json({ posts });
  } catch (error) {
    console.error("Error mengambil posts user:", error);
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const getComments = async (req, res) => {
  try {
    const { postId } = req.params;
    
    const commentsRef = ref(db, `posts/${postId}/comments`);
    const snapshot = await get(commentsRef);
    
    if (!snapshot.exists()) {
      return res.json({ comments: [] });
    }

    const comments = [];
    const commentsData = snapshot.val();

    for (const [commentId, comment] of Object.entries(commentsData)) {
      // Ambil data user untuk setiap komentar
      const userRef = ref(db, `users/${comment.userId}`);
      const userSnapshot = await get(userRef);
      const userData = userSnapshot.val();

      comments.push({
        id: commentId,
        text: comment.text,
        createdAt: comment.createdAt,
        user: {
          id: comment.userId,
          name: userData?.name,
          foto: userData?.fotoProfil
        }
      });
    }

    // Urutkan komentar berdasarkan waktu (terbaru dulu)
    comments.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.json({ comments });
  } catch (error) {
    res.status(500).json({ 
      message: "Terjadi kesalahan server", 
      error: error.message 
    });
  }
};

export const getNotifications = async (req, res) => {
  try {
    const userId = req.user.userId;
    const notificationsRef = ref(db, `notifications/${userId}`);
    const snapshot = await get(notificationsRef);
    
    if (!snapshot.exists()) {
      return res.json({ notifications: [] });
    }

    const notifications = [];
    const notificationsData = snapshot.val();

    for (const [notifId, notification] of Object.entries(notificationsData)) {
      notifications.push({
        id: notifId,
        ...notification,
        fromUserPhoto: notification.fromUserPhoto?.startsWith('http') 
          ? notification.fromUserPhoto 
          : `${process.env.BASE_URL}/${notification.fromUserPhoto}`
      });
    }

    // Urutkan notifikasi berdasarkan waktu (terbaru dulu)
    notifications.sort((a, b) => 
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );

    res.json({ notifications });
    
  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const markNotificationAsRead = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { notificationId } = req.params;
    
    const notificationRef = ref(db, `notifications/${userId}/${notificationId}`);
    await update(notificationRef, { isRead: true });
    
    res.json({ message: "Notifikasi telah ditandai sebagai dibaca" });
  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const getUnreadNotificationsCount = async (req, res) => {
  try {
    const userId = req.user.userId;
    const notificationsRef = ref(db, `notifications/${userId}`);
    const snapshot = await get(notificationsRef);
    
    let count = 0;
    if (snapshot.exists()) {
      const notifications = snapshot.val();
      count = Object.values(notifications).filter(n => !n.isRead).length;
    }
    
    res.json({ count });
  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};

export const getLikeStatus = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { postId } = req.params;

    const likesRef = ref(db, `posts/${postId}/likes`);
    const likesSnapshot = await get(likesRef);

    const likes = likesSnapshot.val() || {};
    const isLiked = likes[userId] ? true : false;

    res.json({ isLiked });
  } catch (error) {
    res.status(500).json({ message: "Terjadi kesalahan server", error: error.message });
  }
};
