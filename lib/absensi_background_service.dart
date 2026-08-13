// file: absensi_background_service.dart
// Handler untuk foreground service tracking lokasi. Jalan di ISOLATE
// TERPISAH dari UI utama -- artinya kode di sini TIDAK bisa langsung
// mengakses state halaman Flutter manapun. Semua yang dibutuhkan (roomId,
// userId) diambil dari SharedPreferences yang ditulis sebelum service
// dimulai.
//
// Karena berjalan independen dari widget tree, service ini TETAP AKTIF
// walau: halaman Absensi Pekerja ditutup, app di-close/di-swipe dari
// recent apps, atau cache aplikasi dihapus. Service HANYA berhenti kalau:
// pekerja menekan Checkout (kita panggil FlutterForegroundTask.stopService()
// secara eksplisit), OS mem-Force-Stop aplikasi secara manual dari
// Settings, atau aplikasi di-uninstall/Clear Data.
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';
import 'geofence_kebun.dart';

const _kPrefRoomId = 'bg_tracker_room_id';
const _kPrefUserId = 'bg_tracker_user_id';
const _kPrefAktif = 'bg_tracker_aktif';

/// Dipanggil dari isolate baru saat service pertama kali start.
/// WAJIB top-level function (bukan method), dan WAJIB anotasi ini supaya
/// tetap ada di build release (tidak di-tree-shake).
///
/// PENTING: flutter_foreground_task menjalankan TaskHandler di ISOLATE
/// TERPISAH dari main isolate -- isolate ini TIDAK otomatis punya akses
/// ke Firebase App yang sudah di-init di main(). Tanpa Firebase.initializeApp()
/// di sini, setiap panggilan FirebaseFirestore.instance akan throw
/// "No Firebase App '[DEFAULT]' has been created", dan karena
/// _catatCheckpointSekarang() membungkusnya dengan try-catch, kegagalan
/// ini akan DIAM-DIAM terjadi terus-menerus tanpa ada yang tahu (checkpoint
/// tidak pernah benar-benar tersimpan ke Firestore).
@pragma('vm:entry-point')
void startAbsensiBackgroundCallback() {
  FlutterForegroundTask.setTaskHandler(_AbsensiTaskHandler());
}

/// Memastikan Firebase sudah siap di isolate ini sebelum dipakai. Aman
/// dipanggil berkali-kali (mis. tiap onRepeatEvent) -- kalau app sudah
/// ada, langsung skip.
Future<void> _pastikanFirebaseSiap() async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class _AbsensiTaskHandler extends TaskHandler {
  final _db = FirebaseFirestore.instance;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Langsung catat 1 checkpoint begitu service mulai (sama seperti
    // perilaku AbsensiLokasiTracker versi foreground lama).
    await _catatCheckpointSekarang();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _catatCheckpointSekarang();
  }

  // PENTING: di flutter_foreground_task versi 8.17.0, onDestroy HANYA
  // menerima 1 parameter (DateTime timestamp) -- TIDAK ada parameter
  // `bool isTimeout` seperti di versi 9.x. Kalau nanti package di-upgrade
  // ke 9.x, signature ini perlu diubah lagi jadi
  // `onDestroy(DateTime timestamp, bool isTimeout)`.
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Tidak ada cleanup khusus -- state sudah di Firestore & SharedPreferences.
  }

  Future<void> _catatCheckpointSekarang() async {
    try {
      await _pastikanFirebaseSiap();

      final prefs = await SharedPreferences.getInstance();
      final aktif = prefs.getBool(_kPrefAktif) ?? false;
      if (!aktif) return;

      final roomId = prefs.getString(_kPrefRoomId);
      final userId = prefs.getString(_kPrefUserId);
      if (roomId == null || userId == null) return;

      final layananAktif = await Geolocator.isLocationServiceEnabled();
      if (!layananAktif) return;

      final izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        return;
      }

      final posisi = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 20),
      );

      final diDalam = GeofenceKebun.isInside(posisi.latitude, posisi.longitude);
      final tanggalHariIni = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docId = '${tanggalHariIni}_$userId';

      // Kalau ternyata dokumen riwayat hari ini sudah ber-checkout (mis.
      // checkout otomatis 17:10 terjadi tapi service ini belum sempat
      // di-stop), hentikan diri sendiri supaya tidak terus jalan sia-sia.
      final riwayatDoc = await _db
          .collection('absensi_rooms')
          .doc(roomId)
          .collection('riwayat')
          .doc(docId)
          .get();
      if (riwayatDoc.data()?['jamCheckout'] != null) {
        await prefs.setBool(_kPrefAktif, false);
        FlutterForegroundTask.stopService();
        return;
      }

      await _db
          .collection('absensi_rooms')
          .doc(roomId)
          .collection('riwayat')
          .doc(docId)
          .collection('lokasiLog')
          .add({
        'waktu': DateTime.now().toIso8601String(),
        'diDalamArea': diDalam,
        'lat': posisi.latitude,
        'lng': posisi.longitude,
      });

      // Update notifikasi supaya pekerja bisa lihat status terkini tanpa
      // harus buka app.
      FlutterForegroundTask.updateService(
        notificationTitle: 'Absensi Kawal Kebun',
        notificationText: diDalam
            ? 'Di dalam area kerja \u00b7 ${DateFormat('HH:mm').format(DateTime.now())}'
            : 'Di luar area kerja \u00b7 ${DateFormat('HH:mm').format(DateTime.now())}',
      );
    } catch (e, st) {
      // Kegagalan checkpoint tunggal (GPS timeout, izin dicabut, dsb)
      // tidak menghentikan service -- dicoba lagi di interval berikutnya.
      // TAPI tetap di-log (bukan diam-diam ditelan) supaya kegagalan
      // berulang tetap kelihatan saat testing / debugging.
      // ignore: avoid_print
      print('AbsensiBackgroundService: gagal catat checkpoint -> $e\n$st');
    }
  }
}

/// API publik dipanggil dari UI (main isolate) untuk mengontrol service.
class AbsensiBackgroundService {
  static Future<void> _init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'absensi_tracking_channel',
        channelName: 'Pelacakan Absensi',
        channelDescription:
            'Menampilkan status pelacakan lokasi selama jam kerja setelah absen Hadir.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30 * 60 * 1000), // 30 menit
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Minta izin yang dibutuhkan: notifikasi (Android 13+), lokasi "Allow
  /// all the time" (background), dan pengecualian battery optimization
  /// (supaya OS tidak agresif membekukan service).
  static Future<bool> mintaSemuaIzin() async {
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      final hasil = await FlutterForegroundTask.requestNotificationPermission();
      if (hasil != NotificationPermission.granted) return false;
    }

    var izinLokasi = await Geolocator.checkPermission();
    if (izinLokasi == LocationPermission.denied) {
      izinLokasi = await Geolocator.requestPermission();
    }
    // Android: minta upgrade ke "Allow all the time" kalau baru "While using app".
    if (izinLokasi == LocationPermission.whileInUse) {
      izinLokasi = await Geolocator.requestPermission();
    }
    if (izinLokasi != LocationPermission.always &&
        izinLokasi != LocationPermission.whileInUse) {
      return false;
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    return true;
  }

  /// Mulai tracking latar belakang untuk 1 pekerja di 1 room. Dipanggil
  /// setelah absen Hadir berhasil.
  static Future<void> mulai({required String roomId, required String userId}) async {
    await _init();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefRoomId, roomId);
    await prefs.setString(_kPrefUserId, userId);
    await prefs.setBool(_kPrefAktif, true);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Absensi Kawal Kebun',
      notificationText: 'Melacak lokasi selama jam kerja Anda.',
      callback: startAbsensiBackgroundCallback,
    );
  }

  /// Hentikan tracking. Dipanggil saat Checkout (manual/otomatis).
  static Future<void> berhenti() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefAktif, false);
    await FlutterForegroundTask.stopService();
  }

  /// Cek apakah SEHARUSNYA ada tracking yang lanjut jalan (dipanggil saat
  /// app dibuka lagi, mis. dari main()) -- untuk kasus proses Dart mati
  /// total lalu dibuka manual oleh pekerja sebelum jam checkout.
  static Future<void> lanjutkanJikaMasihAktif() async {
    final prefs = await SharedPreferences.getInstance();
    final aktif = prefs.getBool(_kPrefAktif) ?? false;
    if (!aktif) return;

    final roomId = prefs.getString(_kPrefRoomId);
    final userId = prefs.getString(_kPrefUserId);
    if (roomId == null || userId == null) return;

    if (!await FlutterForegroundTask.isRunningService) {
      await mulai(roomId: roomId, userId: userId);
    }
  }
}