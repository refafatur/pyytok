import express from "express";
import { createPost, likePost, addComment, sharePost, getAllPosts, getUserPosts, getComments } from "../controllers/authController.js";
import authMiddleware from "../middleware/authMiddleware.js";
import multer from 'multer';
import path from 'path';

const router = express.Router();

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/postingan/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/')) {
    cb(null, true);
  } else {
    cb(new Error('Format file tidak didukung. Hanya gambar dan video yang diizinkan.'), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  }
});

router.post("/create", authMiddleware, upload.single('media'), createPost);
router.post("/:postId/like", authMiddleware, likePost); 
router.post("/:postId/comment", authMiddleware, addComment);
router.post("/:postId/share", authMiddleware, sharePost);
router.get("/", authMiddleware, getAllPosts);
router.get("/user/:userId", authMiddleware, getUserPosts);
router.get("/:postId/comments", authMiddleware, getComments);

export default router;
