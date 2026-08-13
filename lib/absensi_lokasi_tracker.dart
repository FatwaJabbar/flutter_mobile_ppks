// file: absensi_lokasi_tracker.dart
// Melacak lokasi pekerja secara berkala (tiap 30 menit) SELAMA halaman
// Absensi Pekerja terbuka -- TAPI HANYA untuk keperluan UI real-time
// (badge "Di luar area sejak: HH:MM:SS"). TIDAK menulis apapun ke
// Firestore.
//
// PENTING: penulisan checkpoint lokasi ke Firestore (koleksi lokasiLog,
// dipakai untuk grafik aktivitas) SUDAH sepenuhnya ditangani oleh
// AbsensiBackgroundService (foreground service Android di
// absensi_background_service.dart), yang tetap jalan baik selagi app
// terbuka MAUPUN ditutup, dengan interval yang sama (30 menit).
//
// Sebelumnya, tracker foreground ini JUGA menulis ke Firestore lewat
// AbsensiService.catatCheckpointLokasi(...) -- akibatnya selagi halaman
// ini terbuka, ADA 2 checkpoint tercatat tiap 30 menit (satu dari sini,
// satu dari AbsensiBackgroundService), bukan cuma 1. Itu yang bikin data
// lokasiLog kelihatan dobel/numpuk. Sekarang tracker ini murni lokal --
// cuma dipakai buat menghitung status "di dalam/luar area" saat ini agar
// badge di UI bisa update real-time, tanpa ikut menulis data resmi.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'geofence_kebun.dart';

class AbsensiLokasiTracker {
  final String roomId;
  final String userId;
  final Duration interval;

  Timer? _timer;
  Timer? _timerCountdown;
  DateTime? _waktuMulaiDiLuarArea;

  /// Durasi "sejak keluar area" saat ini, null kalau pekerja sedang di
  /// dalam area (tidak ada countdown aktif).
  ///
  /// Dipakai lewat ValueListenableBuilder di UI supaya HANYA widget kecil
  /// yang menampilkan countdown ini yang rebuild tiap detik -- bukan
  /// seluruh halaman (termasuk foto absen), yang sebelumnya menyebabkan
  /// foto terlihat kedip-kedip karena ikut di-decode ulang tiap detik.
  final ValueNotifier<Duration?> countdownDiLuarArea = ValueNotifier<Duration?>(null);

  AbsensiLokasiTracker({
    required this.roomId,
    required this.userId,
    this.interval = const Duration(minutes: 30),
  });

  bool get sedangBerjalan => _timer != null;

  /// Mulai pengecekan lokasi lokal: langsung cek 1x saat dipanggil, lalu
  /// ulangi tiap [interval]. Aman dipanggil berkali-kali (tidak dobel
  /// timer, dan sekarang juga tidak dobel checkpoint Firestore karena
  /// tracker ini sudah tidak menulis ke Firestore sama sekali).
  void mulai() {
    if (_timer != null) return;
    _cekLokasiSekarang();
    _timer = Timer.periodic(interval, (_) => _cekLokasiSekarang());
    _timerCountdown = Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
  }

  void berhenti() {
    _timer?.cancel();
    _timer = null;
    _timerCountdown?.cancel();
    _timerCountdown = null;
    countdownDiLuarArea.value = null;
  }

  /// Panggil di dispose() halaman yang memakai tracker ini, supaya
  /// ValueNotifier-nya dibersihkan dengan benar.
  void dispose() {
    berhenti();
    countdownDiLuarArea.dispose();
  }

  void _tickCountdown() {
    if (_waktuMulaiDiLuarArea == null) {
      countdownDiLuarArea.value = null;
      return;
    }
    countdownDiLuarArea.value = DateTime.now().difference(_waktuMulaiDiLuarArea!);
  }

  /// Cek posisi pekerja SAAT INI, murni buat update status "di luar area
  /// sejak kapan" yang ditampilkan sebagai badge real-time di UI. TIDAK
  /// menulis apapun ke Firestore -- itu tanggung jawab
  /// AbsensiBackgroundService.
  Future<void> _cekLokasiSekarang() async {
    try {
      final layananAktif = await Geolocator.isLocationServiceEnabled();
      if (!layananAktif) return;

      final izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        return;
      }

      final posisi = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      final diDalam = GeofenceKebun.isInside(posisi.latitude, posisi.longitude);

      if (!diDalam && _waktuMulaiDiLuarArea == null) {
        _waktuMulaiDiLuarArea = DateTime.now();
      } else if (diDalam) {
        _waktuMulaiDiLuarArea = null;
      }
    } catch (_) {
      // Diamkan kegagalan cek lokasi tunggal (mis. GPS timeout) -- dicoba
      // lagi di interval berikutnya. Ini cuma untuk badge UI, bukan data
      // resmi yang tersimpan, jadi aman diabaikan.
    }
  }
}