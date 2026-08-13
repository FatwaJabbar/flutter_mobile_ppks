// file: migrate_to_firebase_auth.js
//
// JALANKAN SEKALI SAJA, LOKAL DI KOMPUTER KAMU SENDIRI (bukan di-deploy
// ke Cloud Functions -- jadi TIDAK butuh plan Blaze/bayar).
//
// Yang dilakukan:
// 1. Buat akun Firebase Auth (Email/Password) buat tiap dokumen di
//    `admin` & `users` yang masih punya field `password` plaintext,
//    dengan UID SAMA PERSIS dengan id dokumen Firestore-nya (supaya
//    field ownerId/userId yang sudah ada tetap konsisten).
// 2. Simpan mapping "username -> {uid, loginEmail}" ke collection
//    publik-aman `username_index` (isinya cuma uid & email sintetis,
//    TIDAK ADA password), dipakai app buat cari akun sebelum login.
// 3. Hapus field `password` plaintext dari dokumen `admin`/`users`
//    setelah berhasil dimigrasi -- password aslinya sekarang cuma ada
//    (dalam bentuk hash) di dalam Firebase Auth, tidak pernah lagi di
//    Firestore.
//
// CARA PAKAI:
//   1. Aktifkan dulu provider Email/Password: Firebase Console >
//      Authentication > Sign-in method > Email/Password > Enable.
//      (Ini gratis, tidak butuh Blaze.)
//   2. Download service account key: Firebase Console > Project
//      Settings > Service Accounts > Generate new private key. Simpan
//      sebagai serviceAccountKey.json di folder yang sama dengan file
//      ini. JANGAN commit file ini ke git.
//   3. npm install firebase-admin
//   4. node migrate_to_firebase_auth.js

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();
const auth = getAuth();

const DOMAIN = "kawalkebun.local"; // domain palsu, cuma buat format email

function normalisasi(str) {
  return str.toString().trim().toLowerCase().replace(/\s+/g, "_");
}

async function tulisIndex(key, value) {
  if (!key) return;
  await db.collection("username_index").doc(key).set(value, { merge: true });
}

async function migrasiSatu(doc, collectionName, isAdmin) {
  const data = doc.data();
  const password = (data.password || "").toString();

  if (!password) {
    console.log(`SKIP ${collectionName}/${doc.id}: tidak ada password (mungkin akun Google, atau belum diisi)`);
    return;
  }

  const usernameField = isAdmin ? "username" : "nama";
  const usernameRaw = (data[usernameField] || "").toString().trim();
  if (!usernameRaw) {
    console.log(`SKIP ${collectionName}/${doc.id}: tidak ada ${usernameField}`);
    return;
  }

  const loginEmail = `${normalisasi(usernameRaw)}@${DOMAIN}`;

  // Buat akun Auth kalau belum ada (aman dijalankan berkali-kali).
  try {
    await auth.getUser(doc.id);
    console.log(`SUDAH ADA di Auth: ${doc.id}`);
  } catch (_) {
    await auth.createUser({
      uid: doc.id,
      email: loginEmail,
      password: password,
      displayName: data.nama || usernameRaw,
    });
    console.log(`DIBUAT: ${doc.id} -> ${loginEmail}`);
  }

  // Index publik-aman buat lookup by username (tanpa password).
  await tulisIndex(normalisasi(usernameRaw), {
    uid: doc.id,
    loginEmail,
    isAdmin,
  });
  // Admin bisa login pakai email juga -- index-kan sekalian kalau ada.
  if (isAdmin && data.email) {
    await tulisIndex(normalisasi(data.email), {
      uid: doc.id,
      loginEmail,
      isAdmin,
    });
  }

  // Hapus password plaintext dari Firestore -- selesai dipakai.
  await doc.ref.update({
    password: FieldValue.delete(),
    loginEmail,
  });
}

async function migrasiKoleksi(collectionName, isAdmin) {
  const snap = await db.collection(collectionName).get();
  console.log(`\n=== Migrasi ${collectionName} (${snap.size} dokumen) ===`);
  for (const doc of snap.docs) {
    try {
      await migrasiSatu(doc, collectionName, isAdmin);
    } catch (e) {
      console.error(`GAGAL ${collectionName}/${doc.id}:`, e.message);
    }
  }
}

(async () => {
  await migrasiKoleksi("admin", true);
  await migrasiKoleksi("users", false);
  console.log("\nSelesai. Cek Firebase Console > Authentication untuk lihat akun yang sudah dibuat.");
  process.exit(0);
})();
