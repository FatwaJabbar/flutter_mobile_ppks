import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import math

# ===============================
# 1. Inisialisasi Firebase
# ===============================

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

# ===============================
# 2. Baca File CSV
# ===============================

try:
    df = pd.read_csv("tbs_2026.csv")
    print(df.columns)
    print(df.head())
except Exception as e:
    print("Gagal membaca file CSV:", e)
    exit()

print("Total baris di CSV:", len(df))

# ===============================
# 3. Upload ke Firestore (Batch)
# ===============================

batch = db.batch()
success_count = 0
skip_count = 0

for index, row in df.iterrows():

    # Bersihkan provinsi
    provinsi = str(row["provinsi"]).strip()

    # Validasi harga
    harga = row["harga"]

    if pd.isna(harga):
        skip_count += 1
        continue

    try:
        harga = int(float(harga))
    except:
        skip_count += 1
        continue

    try:
        tahun = int(row["tahun"])
        bulan = int(row["bulan"])
    except:
        skip_count += 1
        continue

    doc_ref = db.collection("tbs_harga").document()
    batch.set(doc_ref, {
        "tahun": tahun,
        "bulan": bulan,
        "provinsi": provinsi,
        "harga": harga
    })

    success_count += 1

    # Commit tiap 400 data (batas Firestore 500)
    if success_count % 400 == 0:
        batch.commit()
        batch = db.batch()
        print(f"{success_count} data berhasil diupload...")

# Commit sisa data
batch.commit()

# ===============================
# 4. Hasil Akhir
# ===============================

print("\n===== SELESAI =====")
print("Berhasil upload :", success_count)
print("Data dilewati   :", skip_count)