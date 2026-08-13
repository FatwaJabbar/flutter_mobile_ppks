/**
 * functions/index.js
 *
 * Pipeline otomatis bulanan:
 * 1. Fetch artikel terbaru dari infosawit.com (CPO & TBS)
 * 2. Kirim teks artikel ke Gemini API untuk diekstrak jadi JSON
 * 3. Validasi hasil
 * 4. Tulis/update ke Firestore: cpo_international & tbs_harga
 *
 * Cara pakai:
 * 1. Copy file ini ke functions/index.js di project Flutter kamu
 *    (folder yang sama dengan file yang dibuat `firebase init functions`)
 * 2. Copy juga functions-package.json isinya ke functions/package.json
 *    (gabungkan dengan yang sudah ada dari firebase init, JANGAN ditimpa
 *    kalau firebase init sudah generate package.json — cukup pastikan
 *    dependency "firebase-admin", "firebase-functions" versinya sesuai)
 * 3. Set secret:
 *      firebase functions:secrets:set GEMINI_API_KEY
 * 4. Deploy:
 *      firebase deploy --only functions
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

// 38 provinsi resmi — dipakai untuk mencocokkan nama provinsi hasil ekstraksi
// Gemini (yang kadang menulis "Kalteng" bukan "Kalimantan Tengah") ke nama baku.
const DAFTAR_PROVINSI = [
  "Aceh", "Sumatera Utara", "Sumatera Barat", "Riau", "Kepulauan Riau",
  "Jambi", "Sumatera Selatan", "Kepulauan Bangka Belitung", "Bengkulu", "Lampung",
  "DKI Jakarta", "Banten", "Jawa Barat", "Jawa Tengah", "Daerah Istimewa Yogyakarta",
  "Jawa Timur", "Bali", "Nusa Tenggara Barat", "Nusa Tenggara Timur",
  "Kalimantan Barat", "Kalimantan Tengah", "Kalimantan Selatan", "Kalimantan Timur", "Kalimantan Utara",
  "Sulawesi Utara", "Gorontalo", "Sulawesi Tengah", "Sulawesi Barat", "Sulawesi Selatan", "Sulawesi Tenggara",
  "Maluku", "Maluku Utara", "Papua", "Papua Barat", "Papua Selatan", "Papua Tengah", "Papua Pegunungan", "Papua Barat Daya",
];

/* ------------------------------------------------------------------ */
/*  Util: panggil Gemini API, minta JSON murni sebagai balasan         */
/* ------------------------------------------------------------------ */
async function geminiExtractJSON(apiKey, prompt) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0,
        responseMimeType: "application/json",
      },
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error("Gemini tidak mengembalikan teks");

  return JSON.parse(text);
}

/* ------------------------------------------------------------------ */
/*  Util: ambil HTML sebagai teks polos (sederhana, cukup untuk artikel */
/*  berita yang strukturnya konsisten)                                  */
/* ------------------------------------------------------------------ */
async function fetchText(url) {
  const res = await fetch(url, {
    headers: { "User-Agent": "Mozilla/5.0 (compatible; KawalKebunBot/1.0)" },
  });
  if (!res.ok) throw new Error(`Gagal fetch ${url}: ${res.status}`);
  const html = await res.text();
  // Strip tag HTML kasar — cukup untuk dikirim ke Gemini sebagai konteks
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 15000); // batasi ukuran biar hemat token
}

/* ------------------------------------------------------------------ */
/*  Ambil daftar link artikel terbaru dari halaman kategori             */
/* ------------------------------------------------------------------ */
async function getLatestArticleLinks(categoryUrl, maxLinks = 15) {
  const res = await fetch(categoryUrl, {
    headers: { "User-Agent": "Mozilla/5.0 (compatible; KawalKebunBot/1.0)" },
  });
  const html = await res.text();

  // Ambil semua href yang mengarah ke pola artikel infosawit: /YYYY/MM/DD/slug/
  const regex = /https:\/\/www\.infosawit\.com\/20\d{2}\/\d{2}\/\d{2}\/[a-z0-9-]+\//g;
  const found = [...new Set(html.match(regex) || [])];
  return found.slice(0, maxLinks);
}

/* ------------------------------------------------------------------ */
/*  1. CPO INTERNATIONAL — ambil artikel harga CPO terbaru              */
/* ------------------------------------------------------------------ */
async function updateCpoInternational(apiKey) {
  const links = await getLatestArticleLinks("https://www.infosawit.com/category/harga-cpo/", 1);
  if (links.length === 0) {
    logger.warn("Tidak ada artikel CPO ditemukan");
    return;
  }

  const articleText = await fetchText(links[0]);

  const prompt = `
Kamu membaca artikel berita bahasa Indonesia tentang harga CPO (crude palm oil) dari KPBN.
Ekstrak informasi berikut dalam JSON murni (tanpa markdown, tanpa penjelasan):
{
  "tahun": <angka 4 digit>,
  "bulan": <angka 1-12>,
  "harga": <angka harga CPO dalam Rupiah per kg, tanpa titik/koma pemisah ribuan, sebagai number>
}
Jika artikel menyebut "withdraw" / tidak ada harga baru, gunakan harga penawaran tertinggi yang disebutkan.
Jika benar-benar tidak ada angka harga sama sekali, kembalikan {"tahun": null, "bulan": null, "harga": null}.

Artikel:
"""
${articleText}
"""
`.trim();

  const extracted = await geminiExtractJSON(apiKey, prompt);

  if (!extracted.tahun || !extracted.bulan || !extracted.harga) {
    logger.warn("Ekstraksi CPO gagal / tidak lengkap", extracted);
    return;
  }

  // Validasi angka masuk akal (harga CPO historisnya di kisaran ini)
  if (extracted.harga < 5000 || extracted.harga > 30000) {
    logger.warn("Harga CPO di luar rentang wajar, dilewati", extracted);
    return;
  }

  const query = await db
    .collection("cpo_international")
    .where("tahun", "==", extracted.tahun)
    .where("bulan", "==", extracted.bulan)
    .limit(1)
    .get();

  if (!query.empty) {
    await query.docs[0].ref.update({ harga: extracted.harga, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    logger.info(`CPO ${extracted.bulan}/${extracted.tahun} di-update: ${extracted.harga}`);
  } else {
    await db.collection("cpo_international").add({
      tahun: extracted.tahun,
      bulan: extracted.bulan,
      harga: extracted.harga,
      sumber: links[0],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`CPO ${extracted.bulan}/${extracted.tahun} ditambahkan: ${extracted.harga}`);
  }
}

/* ------------------------------------------------------------------ */
/*  2. TBS SAWIT — ambil beberapa artikel terbaru, per provinsi         */
/* ------------------------------------------------------------------ */
async function updateTbsHarga(apiKey) {
  const links = await getLatestArticleLinks("https://www.infosawit.com/category/harga-tbs-sawit/", 15);

  for (const link of links) {
    try {
      const articleText = await fetchText(link);

      const prompt = `
Kamu membaca artikel berita bahasa Indonesia tentang harga TBS (Tandan Buah Segar) kelapa sawit.
Ekstrak informasi berikut dalam JSON murni (tanpa markdown, tanpa penjelasan):
{
  "provinsi": <nama provinsi resmi Indonesia, contoh: "Kalimantan Tengah" bukan "Kalteng">,
  "tahun": <angka 4 digit>,
  "bulan": <angka 1-12, bulan awal dari periode penetapan harga>,
  "harga": <angka harga TBS dalam Rupiah per kg, sebagai number. Jika ada beberapa kelas
            umur/jenis (plasma, swadaya, dsb), gunakan rata-rata atau harga kelas umur menengah>
}
Jika artikel tidak membahas harga TBS provinsi tertentu, kembalikan {"provinsi": null}.

Artikel:
"""
${articleText}
"""
`.trim();

      const extracted = await geminiExtractJSON(apiKey, prompt);

      if (!extracted.provinsi || !extracted.tahun || !extracted.bulan || !extracted.harga) {
        continue;
      }

      // Cocokkan nama provinsi ke daftar baku (case-insensitive, partial match)
      const provinsiCocok = DAFTAR_PROVINSI.find(
        (p) => p.toLowerCase() === String(extracted.provinsi).toLowerCase()
      );
      if (!provinsiCocok) {
        logger.warn(`Provinsi tidak dikenali: ${extracted.provinsi}`);
        continue;
      }

      if (extracted.harga < 500 || extracted.harga > 10000) {
        logger.warn("Harga TBS di luar rentang wajar, dilewati", extracted);
        continue;
      }

      const query = await db
        .collection("tbs_harga")
        .where("provinsi", "==", provinsiCocok)
        .where("tahun", "==", extracted.tahun)
        .where("bulan", "==", extracted.bulan)
        .limit(1)
        .get();

      if (!query.empty) {
        await query.docs[0].ref.update({ harga: extracted.harga, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        logger.info(`TBS ${provinsiCocok} ${extracted.bulan}/${extracted.tahun} di-update: ${extracted.harga}`);
      } else {
        await db.collection("tbs_harga").add({
          provinsi: provinsiCocok,
          tahun: extracted.tahun,
          bulan: extracted.bulan,
          harga: extracted.harga,
          sumber: link,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info(`TBS ${provinsiCocok} ${extracted.bulan}/${extracted.tahun} ditambahkan: ${extracted.harga}`);
      }
    } catch (err) {
      logger.error(`Gagal proses artikel TBS ${link}:`, err);
      // lanjut ke artikel berikutnya, jangan hentikan seluruh proses
    }
  }
}

/* ------------------------------------------------------------------ */
/*  Scheduled function — jalan otomatis tanggal 1 tiap bulan, 06:00 WIB  */
/* ------------------------------------------------------------------ */
exports.updateHargaSawitBulanan = onSchedule(
  {
    schedule: "0 6 1 * *", // menit jam tanggal bulan hari — tanggal 1 tiap bulan jam 06:00
    timeZone: "Asia/Jakarta",
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    const apiKey = GEMINI_API_KEY.value();
    await updateCpoInternational(apiKey);
    await updateTbsHarga(apiKey);
    logger.info("Update harga sawit bulanan selesai");
  }
);

/* ------------------------------------------------------------------ */
/*  HTTP trigger manual — untuk testing tanpa nunggu jadwal bulanan     */
/*  Panggil: https://<region>-<project-id>.cloudfunctions.net/testUpdateHargaSawit */
/* ------------------------------------------------------------------ */
exports.testUpdateHargaSawit = onRequest(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 300, memory: "512MiB" },
  async (req, res) => {
    try {
      const apiKey = GEMINI_API_KEY.value();
      await updateCpoInternational(apiKey);
      await updateTbsHarga(apiKey);
      res.status(200).send("OK - data berhasil diupdate");
    } catch (err) {
      logger.error(err);
      res.status(500).send(`Error: ${err.message}`);
    }
  }
);