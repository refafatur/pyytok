import admin from 'firebase-admin';
import serviceAccount from './serviceAccountKey.json' assert { type: "json" };

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://authhub-8a5cf-default-rtdb.firebaseio.com",
});

const db = admin.database();
export default db;