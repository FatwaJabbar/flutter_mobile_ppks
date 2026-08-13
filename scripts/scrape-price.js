/**
 * scrape-price.js
 *
 * Otomatis cari artikel harga TBS & CPO TERBARU dari halaman kategori
 * infosawit.com, ekstrak data terstruktur pakai Gemini, lalu upsert ke
 * Firestore. TIDAK perlu update link manual tiap bulan -- script ini
 * sendiri yang mencari artikel terbaru tiap kali dijalankan.
 *
 * Kenapa ini TIDAK butuh upgrade Blaze:
 * - Script ini jalan di GitHub Actions (server milik GitHub), BUKAN di
 *   Cloud Functions milik project Firebase kamu.
 * - Tulis ke Firestore pakai Firebase Admin SDK (via service account),
 *   yang otomatis bypass Security Rules dan tidak butuh Blaze.
 *
 * Env vars yang dibutuhkan (diisi lewat GitHub Secrets, lihat workflow):
 * - FIREBASE_SERVICE_ACCOUNT_JSON : isi file service-account JSON (string)
 * - GEMINI_API_KEY                : API key Gemini kamu
 *
 * Override manual (opsional, dipakai saat workflow_dispatch dengan input
 * urls_json diisi): [{"type":"tbs","url":"https://..."}]  -- kalau ini
 * diisi, auto-discovery DILEWATI dan hanya URL ini yang diproses. Berguna
 * untuk testing satu artikel spesifik.
 */

const cheerio = require('cheerio');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// ------------------------------------------------------------------
// Konfigurasi sumber
// ------------------------------------------------------------------
const CATEGORY_URLS = {
  cpo: 'https://www.infosawit.com/category/harga-cpo/',
  tbs: 'https://www.infosawit.com/category/harga-tbs-sawit/',
};

// CPO cuma butuh 1 angka global -> cukup ambil artikel terbaru saja.
// TBS beda per provinsi -> perlu banyak artikel terbaru supaya beberapa
// provinsi berbeda ikut ke-cover dalam satu run.
const MAX_LINKS = { cpo: 1, tbs: 20 };

const DAFTAR_PROVINSI = [
  'Aceh', 'Sumatera Utara', 'Sumatera Barat', 'Riau', 'Kepulauan Riau',
  'Jambi', 'Sumatera Selatan', 'Kepulauan Bangka Belitung', 'Bengkulu', 'Lampung',
  'DKI Jakarta', 'Banten', 'Jawa Barat', 'Jawa Tengah', 'Daerah Istimewa Yogyakarta',
  'Jawa Timur', 'Bali', 'Nusa Tenggara Barat', 'Nusa Tenggara Timur',
  'Kalimantan Barat', 'Kalimantan Tengah', 'Kalimantan Selatan', 'Kalimantan Timur', 'Kalimantan Utara',
  'Sulawesi Utara', 'Gorontalo', 'Sulawesi Tengah', 'Sulawesi Barat', 'Sulawesi Selatan', 'Sulawesi Tenggara',
  'Maluku', 'Maluku Utara', 'Papua', 'Papua Barat', 'Papua Selatan', 'Papua Tengah', 'Papua Pegunungan', 'Papua Barat Daya',
];

function initFirebase() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON tidak diset');
  const serviceAccount = JSON.parse(raw);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  return admin.firestore();
}

// ------------------------------------------------------------------
// Cari link artikel terbaru dari halaman kategori
// ------------------------------------------------------------------
async function getLatestArticleLinks(categoryUrl, maxLinks) {
  const res = await fetch(categoryUrl, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; HargaSawitBot/1.0)' },
  });
  if (!res.ok) throw new Error(`Gagal fetch kategori ${categoryUrl}: HTTP ${res.status}`);
  const html = await res.text();

  // Pola URL artikel infosawit: https://www.infosawit.com/YYYY/MM/DD/slug/
  const regex = /https:\/\/www\.infosawit\.com\/20\d{2}\/\d{2}\/\d{2}\/[a-z0-9-]+\//g;
  const found = [...new Set(html.match(regex) || [])];
  // Halaman kategori mengurutkan dari yang terbaru ke terlama, jadi urutan
  // hasil match (top-to-bottom di HTML) sudah "terbaru dulu".
  return found.slice(0, maxLinks);
}

async function fetchArticleText(url) {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; HargaSawitBot/1.0)' },
  });
  if (!res.ok) throw new Error(`Gagal fetch ${url}: HTTP ${res.status}`);
  const html = await res.text();

  const $ = cheerio.load(html);
  $('script, style, nav, footer, header, .comments, .related-posts').remove();

  let content = $('article').text() || $('.entry-content').text() || $('main').text();
  if (!content || content.trim().length < 50) content = $('body').text();

  const title = $('title').first().text().trim();
  const text = `${title}\n\n${content}`.replace(/\s+/g, ' ').trim();
  return text.slice(0, 8000); // batasi biar hemat token
}

async function extractWithGemini(genAI, articleText, type) {
  // Pakai alias "-latest" bukan versi tetap (mis. "gemini-2.0-flash"), supaya
  // otomatis ikut versi Flash terbaru dan tidak rusak saat Google pensiunkan
  // model lama.
  const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });

  const schemaHint =
    type === 'tbs'
      ? `{"provinsi": string (nama provinsi baku, contoh "Jambi", "Riau"), "tahun": number, "bulan": number (1-12), "harga": number (harga rata-rata TBS dalam Rupiah per Kg, angka saja tanpa titik/koma ribuan)}`
      : `{"tahun": number, "bulan": number (1-12), "harga": number (harga CPO internasional dalam Rupiah per kg, angka saja)}`;

  const prompt = `Kamu akan menerima teks artikel berita harga sawit berbahasa Indonesia.

TEKS ARTIKEL:
"""${articleText}"""

Tugas kamu: ekstrak SATU data harga dari artikel ini dalam format JSON PERSIS seperti skema berikut. Jangan tambahkan teks lain, jangan pakai markdown code fence.

Skema:
${schemaHint}

Aturan:
- Bulan dan tahun diambil dari PERIODE harga yang disebutkan di artikel (misal "6-12 Maret 2026" -> bulan 3, tahun 2026), bukan tanggal artikel dipublikasikan kalau berbeda.
- Kalau ada rentang umur/kelas TBS dengan harga berbeda-beda, ambil angka rata-rata atau harga TBS umur 10-20 tahun kalau disebutkan sebagai acuan; kalau tidak ada rata-rata eksplisit, hitung rata-rata sederhana dari angka-angka yang ada.
- Kalau data yang diminta tidak ditemukan di artikel, balas dengan {"error": "tidak ditemukan"} saja.`;

  const result = await model.generateContent(prompt);
  const raw = result.response.text().trim().replace(/```json|```/g, '').trim();
  return JSON.parse(raw);
}

async function upsertTBS(db, data, sumber) {
  if (!data.provinsi || !data.tahun || !data.bulan || !data.harga) {
    throw new Error(`Data TBS tidak lengkap: ${JSON.stringify(data)}`);
  }

  // Cocokkan ke nama provinsi baku (kadang Gemini menulis "Kalteng" dsb.)
  const provinsiCocok = DAFTAR_PROVINSI.find(
    (p) => p.toLowerCase() === String(data.provinsi).toLowerCase()
  );
  if (!provinsiCocok) {
    console.warn(`[SKIP] Provinsi tidak dikenali: ${data.provinsi}`);
    return null;
  }

  if (data.harga < 500 || data.harga > 10000) {
    console.warn('[SKIP] Harga TBS di luar rentang wajar, dilewati', data);
    return null;
  }

  const docId = `${provinsiCocok}_${data.tahun}_${data.bulan}`
    .toLowerCase()
    .replace(/\s+/g, '-');
  await db.collection('tbs_harga').doc(docId).set(
    {
      provinsi: provinsiCocok,
      tahun: data.tahun,
      bulan: data.bulan,
      harga: data.harga,
      sumber,
      diperbarui: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`[OK] tbs_harga/${docId} ->`, { provinsi: provinsiCocok, ...data });
  return `${provinsiCocok}_${data.tahun}_${data.bulan}`;
}

async function upsertCPO(db, data, sumber) {
  if (!data.tahun || !data.bulan || !data.harga) {
    throw new Error(`Data CPO tidak lengkap: ${JSON.stringify(data)}`);
  }
  const docId = `global_${data.tahun}_${data.bulan}`;
  await db.collection('cpo_international').doc(docId).set(
    {
      negara: 'global',
      tahun: data.tahun,
      bulan: data.bulan,
      harga: data.harga,
      sumber,
      diperbarui: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`[OK] cpo_international/${docId} ->`, data);
}

// ------------------------------------------------------------------
// Proses satu tipe (cpo / tbs): cari link terbaru, ekstrak, upsert.
// Untuk TBS, artikel diproses berurutan dari yang PALING BARU; kalau ada
// provinsi yang sudah dapat data di run yang sama, artikel provinsi itu
// yang lebih lama (duplikat) di-skip supaya tidak menimpa data yang lebih
// baru dengan yang lebih lama.
// ------------------------------------------------------------------
async function processCategory(db, genAI, type) {
  const links = await getLatestArticleLinks(CATEGORY_URLS[type], MAX_LINKS[type]);
  if (links.length === 0) {
    console.warn(`Tidak ada artikel ${type} ditemukan di halaman kategori`);
    return { gagal: 0 };
  }

  const sudahDiproses = new Set(); // key: provinsi_tahun_bulan (tbs only)
  let gagal = 0;

  for (const url of links) {
    try {
      console.log(`Memproses (${type}): ${url}`);
      const text = await fetchArticleText(url);
      const data = await extractWithGemini(genAI, text, type);

      if (data.error) {
        console.warn(`[SKIP] ${url}: ${data.error}`);
        continue;
      }

      if (type === 'tbs') {
        const key = `${String(data.provinsi).toLowerCase()}_${data.tahun}_${data.bulan}`;
        if (sudahDiproses.has(key)) {
          console.log(`[SKIP] Sudah ada data lebih baru untuk ${data.provinsi} ${data.bulan}/${data.tahun}, lewati duplikat lama`);
          continue;
        }
        const written = await upsertTBS(db, data, url);
        if (written) sudahDiproses.add(written.toLowerCase());
      } else {
        await upsertCPO(db, data, url);
      }
    } catch (e) {
      gagal++;
      console.error(`[GAGAL] ${url}:`, e.message);
    }
  }

  return { gagal };
}

async function main() {
  const db = initFirebase();
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

  let totalGagal = 0;

  // Override manual (opsional): kalau workflow_dispatch diisi urls_json,
  // proses HANYA url itu, lewati auto-discovery. Berguna untuk testing.
  if (process.env.URLS_JSON && process.env.URLS_JSON.trim().length > 0) {
    const items = JSON.parse(process.env.URLS_JSON);
    for (const item of items) {
      try {
        console.log(`[MANUAL] Memproses (${item.type}): ${item.url}`);
        const text = await fetchArticleText(item.url);
        const data = await extractWithGemini(genAI, text, item.type);
        if (data.error) {
          console.warn(`[SKIP] ${item.url}: ${data.error}`);
          continue;
        }
        if (item.type === 'tbs') await upsertTBS(db, data, item.url);
        else if (item.type === 'cpo') await upsertCPO(db, data, item.url);
      } catch (e) {
        totalGagal++;
        console.error(`[GAGAL] ${item.url}:`, e.message);
      }
    }
  } else {
    // Mode normal: auto-discovery dari halaman kategori.
    const hasilCpo = await processCategory(db, genAI, 'cpo');
    const hasilTbs = await processCategory(db, genAI, 'tbs');
    totalGagal = hasilCpo.gagal + hasilTbs.gagal;
  }

  if (totalGagal > 0) process.exitCode = 1;
}

main();