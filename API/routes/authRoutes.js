import express from "express";
import { register, login, userProfile, editProfile, logout, getNotifications, markNotificationAsRead, getUnreadNotificationsCount } from "../controllers/authController.js";
import authMiddleware from "../middleware/authMiddleware.js";
import multer from 'multer';
import path from 'path';

const router = express.Router();

// Konfigurasi multer untuk upload file
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/profil/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  console.log('Uploaded file mimetype:', file.mimetype);
  
  const allowedMimeTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp'
  ];

  if (allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`Format file tidak didukung. Hanya file gambar yang diizinkan (${allowedMimeTypes.join(', ')})`), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit untuk foto profil
  }
});

// Rute autentikasi
router.post("/register", upload.single('foto'), register);
router.post("/login", login);
router.get("/user-profile", authMiddleware, userProfile);
router.put("/edit-profile", authMiddleware, upload.single('foto'), editProfile);
router.post("/logout", authMiddleware, logout);
router.get("/notifications", authMiddleware, getNotifications);
router.post("/notifications/:notificationId/read", authMiddleware, markNotificationAsRead);
router.get("/notifications/unread/count", authMiddleware, getUnreadNotificationsCount);

export default router;
