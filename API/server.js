import express from "express";
import bodyParser from "body-parser";
import cors from "cors";
import authRoutes from "./routes/authRoutes.js";
import postRoutes from "./routes/postRoutes.js";
import dotenv from "dotenv";
import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Dapatkan __dirname untuk ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config();

// Verifikasi SECRET_KEY
if (!process.env.SECRET_KEY) {
  console.error('SECRET_KEY tidak ditemukan di environment variables');
  process.exit(1);
}

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Routes
app.use("/auth", authRoutes);
app.use("/posts", postRoutes);

// Gunakan join untuk path yang benar
app.use('/uploads', express.static(join(__dirname, 'uploads')));
app.use('/uploads/profil', express.static(join(__dirname, 'uploads/profil')));
app.use('/uploads/postingan', express.static(join(__dirname, 'uploads/postingan')));

// Buat direktori uploads dan subfoldernya
const uploadsDir = join(__dirname, 'uploads');
const postinganDir = join(uploadsDir, 'postingan');
const profilDir = join(uploadsDir, 'profil');

if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir);
}
if (!fs.existsSync(postinganDir)) {
  fs.mkdirSync(postinganDir);
}
if (!fs.existsSync(profilDir)) {
  fs.mkdirSync(profilDir);
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
