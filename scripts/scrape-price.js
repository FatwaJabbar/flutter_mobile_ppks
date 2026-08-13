/**
 * scrape-price.js
 *
 * Ambil artikel harga TBS / CPO dari infosawit.com (atau situs sejenis),
 * ekstrak data terstruktur pakai Gemini, lalu upsert ke Firestore.
 *
 * Kenapa ini TIDAK butuh upgrade Blaze:
 * - Script ini jalan di GitHub Actions (server milik GitHub), BUKAN di
 *   Cloud Functions milik project Firebase kamu. Jadi tidak menyentuh
 *   kuota/izin Blaze sama sekali.
 * - Tulis ke Firestore pakai Firebase Admin SDK (via service account),
 *   yang otomatis bypass Security Rules dan tidak butuh Blaze -- baca/
 *   tulis Firestore itu sendiri gratis di Spark plan, yang butuh Blaze
 *   cuma Cloud Functions/Cloud Scheduler kalau mau jalan DI DALAM
 *   Firebase.
 *
 * Env vars yang dibutuhkan (diisi lewat GitHub Secrets, lihat workflow):
 * - FIREBASE_SERVICE_ACCOUNT_JSON : isi file service-account JSON (string)
 * - GEMINI_API_KEY                : API key Gemini kamu
 *
 * Sumber artikel yang mau di-scrape diambil dari sources.json (lihat
 * file itu) -- edit filenya tiap bulan dengan link artikel terbaru.
 */

const fs = require('fs');
const path = require('path');
const cheerio = require('cheerio');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

function initFirebase() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON tidak diset');
  const serviceAccount = JSON.parse(raw);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  return admin.firestore();
}

async function fetchArticleText(url) {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; HargaSawitBot/1.0)' },
  });
  if (!res.ok) throw new Error(`Gagal fetch ${url}: HTTP ${res.status}`);
  const html = await res.text();

  const $ = cheerio.load(html);
  $('script, style, nav, footer, header, .comments, .related-posts').remove();

  // infosawit.com menaruh isi artikel di <article> atau .entry-content,
  // fallback ke <body> kalau strukturnya beda.
  let content = $('article').text() || $('.entry-content').text() || $('main').text();
  if (!content || content.trim().length < 50) content = $('body').text();

  const title = $('title').first().text().trim();
  const text = `${title}\n\n${content}`.replace(/\s+/g, ' ').trim();
  return text.slice(0, 8000); // batasi biar hemat token
}

async function extractWithGemini(genAI, articleText, type) {
  const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

  const schemaHint =
    type === 'tbs'
      ? `{"provinsi": string (nama provinsi, gunakan penulisan baku, contoh "Jambi", "Riau"), "tahun": number, "bulan": number (1-12), "harga": number (harga rata-rata TBS dalam Rupiah per Kg, angka saja tanpa titik/koma ribuan)}`
      : `{"tahun": number, "bulan": number (1-12), "harga": number (harga CPO internasional, angka saja, sebutkan satuan asli di field "satuan")}`;

  const prompt = `Kamu akan menerima teks artikel berita harga sawit berbahasa Indonesia.

TEKS ARTIKEL:
"""${articleText}"""

Tugas kamu: ekstrak SATU data harga dari artikel ini dalam format JSON PERSIS seperti skema berikut. Jangan tambahkan teks lain, jangan pakai markdown code fence.

Skema:
${schemaHint}

Aturan:
- Bulan dan tahun diambil dari PERIODE harga yang disebutkan di artikel (misal "6-12 Maret 2026" -> bulan 3, tahun 2026), bukan tanggal artikel dipublikasikan kalau berbeda.
- Kalau ada rentang umur/kelas TBS dengan harga berbeda-beda, ambil angka "rata-rata" atau harga TBS umur 10-20 tahun kalau disebutkan sebagai acuan; kalau tidak ada rata-rata eksplisit, hitung rata-rata sederhana dari angka-angka yang ada.
- Kalau data yang diminta tidak ditemukan di artikel, balas dengan {"error": "tidak ditemukan"} saja.`;

  const result = await model.generateContent(prompt);
  const raw = result.response.text().trim().replace(/```json|```/g, '').trim();
  return JSON.parse(raw);
}

async function upsertTBS(db, data) {
  if (!data.provinsi || !data.tahun || !data.bulan || !data.harga) {
    throw new Error(`Data TBS tidak lengkap: ${JSON.stringify(data)}`);
  }
  const docId = `${data.provinsi}_${data.tahun}_${data.bulan}`
    .toLowerCase()
    .replace(/\s+/g, '-');
  await db.collection('tbs_harga').doc(docId).set(
    {
      provinsi: data.provinsi,
      tahun: data.tahun,
      bulan: data.bulan,
      harga: data.harga,
      sumber: 'auto-scrape',
      diperbarui: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`[OK] tbs_harga/${docId} ->`, data);
}

async function upsertCPO(db, data) {
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
      sumber: 'auto-scrape',
      diperbarui: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`[OK] cpo_international/${docId} ->`, data);
}

async function main() {
  const db = initFirebase();
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

  // Sumber diambil dari env override (dipakai saat workflow_dispatch manual)
  // atau dari sources.json kalau tidak ada override (dipakai saat cron).
  let sources;
  if (process.env.URLS_JSON && process.env.URLS_JSON.trim().length > 0) {
    sources = JSON.parse(process.env.URLS_JSON);
  } else {
    const file = path.join(__dirname, 'sources.json');
    sources = JSON.parse(fs.readFileSync(file, 'utf8'));
  }

  let gagal = 0;
  for (const item of sources) {
    try {
      console.log(`Memproses (${item.type}): ${item.url}`);
      const text = await fetchArticleText(item.url);
      const data = await extractWithGemini(genAI, text, item.type);

      if (data.error) {
        console.warn(`[SKIP] ${item.url}: ${data.error}`);
        continue;
      }
      if (item.type === 'tbs') await upsertTBS(db, data);
      else if (item.type === 'cpo') await upsertCPO(db, data);
      else console.warn(`[SKIP] tipe tidak dikenal: ${item.type}`);
    } catch (e) {
      gagal++;
      console.error(`[GAGAL] ${item.url}:`, e.message);
    }
  }

  if (gagal > 0) process.exitCode = 1;
}

main();
