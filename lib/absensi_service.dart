// file: absensi_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'absensi_models.dart';
import 'absensi_aktivitas_models.dart';

class AbsensiService {
  static final _db = FirebaseFirestore.instance;

  // ================= DEBUG / TESTING ONLY =================
  // Dikembalikan ke `false` untuk perilaku produksi normal: tombol
  // Checkout HANYA aktif mulai jam 17:00, dan checkout otomatis tetap
  // mengikuti jadwal aslinya (17:10). Kalau butuh testing lagi tanpa
  // nunggu jam beneran, set sementara ke `true` -- TAPI WAJIB
  // dikembalikan ke `false` lagi sebelum build rilis, karena kalau lupa,
  // tombol Checkout akan aktif 24 jam untuk semua pekerja.
  static const bool debugBypassBatasCheckout = false;

  // Batas absen tepat waktu: 07:40
  static const int jamBatasTelat = 7;
  static const int menitBatasTelat = 40;

  // Batas terakhir bisa mengakses tombol Hadir/Izin/Sakit: 12:00 siang.
  // Lewat dari jam ini, pekerja yang belum tercatat otomatis ditandai Alpha.
  static const int jamBatasAlpha = 12;
  static const int menitBatasAlpha = 0;

  // Tombol Checkout baru aktif mulai jam 17:00.
  static const int jamBatasCheckout = 17;
  static const int menitBatasCheckout = 0;

  // Kalau sampai 17:10 pekerja belum menekan Checkout, sistem checkout
  // otomatis (tanpa keterangan) supaya grafik aktivitas hari itu tetap
  // pasti terbentuk setiap hari.
  static const int jamBatasCheckoutOtomatis = 17;
  static const int menitBatasCheckoutOtomatis = 10;

  // ================= GENERATE KODE AKSES =================
  static String _generateKodeAkses() {
    // tanpa 0/O/1/I biar tidak gampang salah baca saat dibagikan
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final kode = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'KBN-$kode';
  }

  // ================= ROOM PEMILIK =================
  static Future<AbsensiRoom?> getRoomByOwner(String ownerId) async {
    final snap = await _db
        .collection('absensi_rooms')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AbsensiRoom.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  static Future<AbsensiRoom> createRoom({
    required String ownerId,
    required String ownerNama,
    required String namaKebun,
  }) async {
    String kode;
    while (true) {
      kode = _generateKodeAkses();
      final cek = await _db
          .collection('absensi_rooms')
          .where('kodeAkses', isEqualTo: kode)
          .limit(1)
          .get();
      if (cek.docs.isEmpty) break;
    }

    final ref = await _db.collection('absensi_rooms').add({
      'ownerId': ownerId,
      'ownerNama': ownerNama,
      'namaKebun': namaKebun,
      'kodeAkses': kode,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return AbsensiRoom(
      roomId: ref.id,
      ownerId: ownerId,
      ownerNama: ownerNama,
      namaKebun: namaKebun,
      kodeAkses: kode,
      createdAt: DateTime.now(),
    );
  }

  static Stream<List<AnggotaAbsensi>> streamAnggota(String roomId) {
    return _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('anggota')
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AnggotaAbsensi.fromMap(d.data())).toList());
  }

  // ================= ROOM PEKERJA =================
  static Future<AbsensiRoom?> getRoomByKode(String kodeAkses) async {
    final kodeBersih = kodeAkses.trim().toUpperCase();
    final snap = await _db
        .collection('absensi_rooms')
        .where('kodeAkses', isEqualTo: kodeBersih)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AbsensiRoom.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  static Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String nama,
  }) async {
    await _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('anggota')
        .doc(userId)
        .set({
      'userId': userId,
      'nama': nama,
      'joinedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    await _db.collection('users').doc(userId).set({
      'absensiRoomId': roomId,
    }, SetOptions(merge: true));
  }

  static Future<String?> getMyRoomId(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['absensiRoomId'];
  }

  static Future<void> keluarDariRoom(String userId) async {
    await _db.collection('users').doc(userId).set({
      'absensiRoomId': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  /// Mengeluarkan pekerja dari room absensi (dipakai oleh PEMILIK).
  static Future<void> kickAnggota({
    required String roomId,
    required String userId,
  }) async {
    await _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('anggota')
        .doc(userId)
        .delete();

    final userDoc = await _db.collection('users').doc(userId).get();
    if (userDoc.data()?['absensiRoomId'] == roomId) {
      await _db.collection('users').doc(userId).set({
        'absensiRoomId': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }

  // ================= ABSEN HARIAN =================
  static String get tanggalHariIni => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static bool sudahLewatBatasAlpha([DateTime? waktu]) {
    final now = waktu ?? DateTime.now();
    final batas = DateTime(now.year, now.month, now.day, jamBatasAlpha, menitBatasAlpha);
    return now.isAfter(batas);
  }

  /// True kalau tombol Checkout sudah boleh ditekan (mulai jam 17:00).
  static bool sudahBolehCheckout([DateTime? waktu]) {
    if (debugBypassBatasCheckout) return true;
    final now = waktu ?? DateTime.now();
    final batas = DateTime(now.year, now.month, now.day, jamBatasCheckout, menitBatasCheckout);
    return !now.isBefore(batas);
  }

  /// True kalau sudah lewat batas checkout otomatis (17:10).
  /// Catatan: dengan debugBypassBatasCheckout aktif, fungsi ini SENGAJA
  /// tetap dibiarkan pakai jam asli (bukan ikut di-bypass) supaya
  /// checkout otomatis di background TIDAK mendadak trigger duluan
  /// sebelum kamu sempat tekan tombol Checkout manual untuk testing.
  static bool sudahLewatBatasCheckoutOtomatis([DateTime? waktu]) {
    final now = waktu ?? DateTime.now();
    final batas =
        DateTime(now.year, now.month, now.day, jamBatasCheckoutOtomatis, menitBatasCheckoutOtomatis);
    return now.isAfter(batas);
  }

  static Stream<List<RiwayatAbsensi>> streamRiwayatHariIni(String roomId) {
    return _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('riwayat')
        .where('tanggal', isEqualTo: tanggalHariIni)
        .snapshots()
        .map((s) => s.docs.map((d) => RiwayatAbsensi.fromMap(d.id, d.data())).toList());
  }

  static Future<RiwayatAbsensi?> getStatusHariIni({
    required String roomId,
    required String userId,
  }) async {
    final snap = await _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('riwayat')
        .where('tanggal', isEqualTo: tanggalHariIni)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return RiwayatAbsensi.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  static Future<void> catatAbsensi({
    required String roomId,
    required String userId,
    required String nama,
    required String fotoBase64,
    required double lat,
    required double lng,
    required StatusAbsensi jenis,
    String? keterangan,
  }) async {
    final now = DateTime.now();
    final jamStr = DateFormat('HH:mm:ss').format(now);
    final statusFinal = jenis == StatusAbsensi.hadir ? _hitungStatus(now) : jenis;

    final docId = '${tanggalHariIni}_$userId';
    await _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('riwayat')
        .doc(docId)
        .set({
      'userId': userId,
      'nama': nama,
      'tanggal': tanggalHariIni,
      'jam': jamStr,
      'status': statusFinal.name,
      'foto': fotoBase64,
      'lat': lat,
      'lng': lng,
      if (keterangan != null && keterangan.isNotEmpty) 'keterangan': keterangan,
    });
  }

  static StatusAbsensi _hitungStatus(DateTime waktu) {
    final batas = DateTime(waktu.year, waktu.month, waktu.day, jamBatasTelat, menitBatasTelat);
    return waktu.isAfter(batas) ? StatusAbsensi.telat : StatusAbsensi.hadir;
  }

  static Future<void> catatAlphaOtomatis({
    required String roomId,
    required String userId,
    required String nama,
  }) async {
    final docId = '${tanggalHariIni}_$userId';
    final ref = _db.collection('absensi_rooms').doc(roomId).collection('riwayat').doc(docId);

    final existing = await ref.get();
    if (existing.exists) return;

    await ref.set({
      'userId': userId,
      'nama': nama,
      'tanggal': tanggalHariIni,
      'jam': DateFormat('HH:mm:ss').format(DateTime.now()),
      'status': StatusAbsensi.alpha.name,
      'keterangan': 'Tidak melakukan absensi sampai batas waktu pukul 12:00 (otomatis oleh sistem)',
    });
  }

  // ================= CHECKPOINT LOKASI & AKTIVITAS HARIAN =================

  /// Menyimpan satu titik checkpoint lokasi (dipanggil tiap 30 menit
  /// selama pekerja berstatus Hadir/Telat dan belum Checkout hari ini).
  /// Disimpan sebagai sub-collection di bawah dokumen riwayat pekerja.
  static Future<void> catatCheckpointLokasi({
    required String roomId,
    required String userId,
    required LokasiCheckpoint checkpoint,
  }) async {
    final docId = '${tanggalHariIni}_$userId';
    await _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('riwayat')
        .doc(docId)
        .collection('lokasiLog')
        .add(checkpoint.toMap());
  }

  /// Ambil seluruh checkpoint lokasi hari ini (atau [tanggal] tertentu)
  /// untuk satu pekerja, terurut dari yang paling awal. Dipakai untuk
  /// menghitung ringkasan aktivitas & menampilkan grafik.
  static Future<List<LokasiCheckpoint>> getLokasiLogHariIni({
    required String roomId,
    required String userId,
    String? tanggal,
  }) async {
    final docId = '${tanggal ?? tanggalHariIni}_$userId';
    final snap = await _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('riwayat')
        .doc(docId)
        .collection('lokasiLog')
        .orderBy('waktu')
        .get();
    return snap.docs.map((d) => LokasiCheckpoint.fromMap(d.data())).toList();
  }

  /// Menghitung ringkasan aktivitas (menit di dalam/luar area, jumlah kali
  /// keluar area) dari kumpulan checkpoint sepanjang hari. Setiap
  /// checkpoint dianggap mewakili durasi [intervalMenit] (default 30
  /// menit, sesuai jadwal pengecekan lokasi) sejak checkpoint sebelumnya.
  static RingkasanAktivitas hitungRingkasan(
    List<LokasiCheckpoint> checkpoints, {
    int intervalMenit = 30,
  }) {
    if (checkpoints.isEmpty) return RingkasanAktivitas.kosong();

    int menitDalam = 0;
    int menitLuar = 0;
    int keluarArea = 0;
    bool? statusSebelumnya;

    for (final c in checkpoints) {
      if (c.diDalamArea) {
        menitDalam += intervalMenit;
      } else {
        menitLuar += intervalMenit;
      }
      if (statusSebelumnya == true && c.diDalamArea == false) {
        keluarArea++;
      }
      statusSebelumnya = c.diDalamArea;
    }

    return RingkasanAktivitas(
      totalMenitDiDalam: menitDalam,
      totalMenitDiLuar: menitLuar,
      jumlahKeluarArea: keluarArea,
      totalCheckpoint: checkpoints.length,
    );
  }

  /// True kalau pekerja SUDAH absen (Hadir/Telat) hari ini TAPI belum
  /// Checkout -- dipakai untuk menampilkan tombol Checkout & memutuskan
  /// apakah tracker lokasi harus berjalan.
  static bool bisaCheckout(RiwayatAbsensi? status) {
    if (status == null) return false;
    final sudahHadir = status.status == StatusAbsensi.hadir || status.status == StatusAbsensi.telat;
    return sudahHadir && status.jamCheckout == null;
  }

  /// Proses Checkout (manual ATAU otomatis). Mengambil seluruh checkpoint
  /// lokasi hari ini, menghitung ringkasan aktivitas, lalu menyimpannya ke
  /// dokumen riwayat pekerja supaya grafik aktivitas hariannya siap dilihat.
  ///
  /// [otomatis] = true kalau dipicu sistem karena pekerja tidak menekan
  /// tombol Checkout sampai batas waktu 17:10 (lihat
  /// [sudahLewatBatasCheckoutOtomatis]). Tidak ada keterangan yang diminta
  /// ke pekerja untuk kasus ini -- prosesnya murni backend, supaya grafik
  /// tetap pasti terbentuk setiap hari.
  static Future<RingkasanAktivitas> catatCheckout({
    required String roomId,
    required String userId,
    bool otomatis = false,
  }) async {
    final docId = '${tanggalHariIni}_$userId';
    final ref = _db.collection('absensi_rooms').doc(roomId).collection('riwayat').doc(docId);

    final doc = await ref.get();
    if (!doc.exists) {
      // Belum ada record absen hari ini -- seharusnya tidak terjadi karena
      // checkout hanya tersedia setelah absen Hadir/Telat.
      return RingkasanAktivitas.kosong();
    }
    if (doc.data()?['jamCheckout'] != null) {
      // Sudah pernah checkout, jangan ditimpa.
      return RingkasanAktivitas.fromMap(
          doc.data()?['ringkasanAktivitas'] as Map<String, dynamic>?);
    }

    final checkpoints = await getLokasiLogHariIni(roomId: roomId, userId: userId);
    final ringkasan = hitungRingkasan(checkpoints);

    await ref.set({
      'jamCheckout': DateFormat('HH:mm:ss').format(DateTime.now()),
      'checkoutOtomatis': otomatis,
      'ringkasanAktivitas': ringkasan.toMap(),
    }, SetOptions(merge: true));

    return ringkasan;
  }

  // ================= RIWAYAT (dipakai di dalam halaman Absensi) =================
  static Future<List<RiwayatAbsensi>> getRiwayatRoom({
    required String roomId,
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('absensi_rooms')
        .doc(roomId)
        .collection('riwayat');

    if (start != null) {
      q = q.where('tanggal', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(start));
    }
    if (end != null) {
      q = q.where('tanggal', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(end));
    }
    if (userId != null) {
      q = q.where('userId', isEqualTo: userId);
    }

    final snap = await q.orderBy('tanggal', descending: true).get();
    return snap.docs.map((d) => RiwayatAbsensi.fromMap(d.id, d.data())).toList();
  }

  static Future<({String roomId, bool sayaPemilik})?> cariRoomSaya(String userId) async {
    final roomPemilik = await getRoomByOwner(userId);
    if (roomPemilik != null) {
      return (roomId: roomPemilik.roomId, sayaPemilik: true);
    }
    final roomId = await getMyRoomId(userId);
    if (roomId != null && roomId.isNotEmpty) {
      return (roomId: roomId, sayaPemilik: false);
    }
    return null;
  }
}