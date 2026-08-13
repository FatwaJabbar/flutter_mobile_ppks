// file: absensi_models.dart

import 'package:flutter/material.dart';

import 'absensi_aktivitas_models.dart';

class AbsensiRoom {
  final String roomId;
  final String ownerId;
  final String ownerNama;
  final String namaKebun;
  final String kodeAkses;
  final DateTime createdAt;

  AbsensiRoom({
    required this.roomId,
    required this.ownerId,
    required this.ownerNama,
    required this.namaKebun,
    required this.kodeAkses,
    required this.createdAt,
  });

  factory AbsensiRoom.fromMap(String id, Map<String, dynamic> data) {
    return AbsensiRoom(
      roomId: id,
      ownerId: data['ownerId'] ?? '',
      ownerNama: data['ownerNama'] ?? '',
      namaKebun: data['namaKebun'] ?? '',
      kodeAkses: data['kodeAkses'] ?? '',
      createdAt: (data['createdAt'] is String)
          ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class AnggotaAbsensi {
  final String userId;
  final String nama;
  final DateTime joinedAt;

  AnggotaAbsensi({
    required this.userId,
    required this.nama,
    required this.joinedAt,
  });

  factory AnggotaAbsensi.fromMap(Map<String, dynamic> data) {
    return AnggotaAbsensi(
      userId: data['userId'] ?? '',
      nama: data['nama'] ?? '',
      joinedAt: (data['joinedAt'] is String)
          ? DateTime.tryParse(data['joinedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Status absensi harian:
/// - `hadir` / `telat` dihitung OTOMATIS oleh server berdasarkan jam saat
///   pekerja menekan tombol Hadir (lihat AbsensiService._hitungStatus).
/// - `izin` / `sakit` dipilih manual oleh pekerja lewat tombol masing-masing.
/// - `alpha` dicatat OTOMATIS oleh sistem kalau sampai jam 12:00 siang
///   pekerja belum melakukan absen apapun (lihat
///   AbsensiService.catatAlphaOtomatis).
/// - `belum` bukan status tersimpan di database, hanya representasi
///   "belum ada record hari ini" di sisi UI.
enum StatusAbsensi { hadir, telat, izin, sakit, alpha, belum }

class RiwayatAbsensi {
  final String id;
  final String userId;
  final String nama;
  final String tanggal; // format yyyy-MM-dd
  final String jam; // format HH:mm:ss
  final StatusAbsensi status;
  final String? fotoBase64;
  final String? keterangan; // dipakai untuk izin, sakit & alpha
  final double? lat;
  final double? lng;

  // ===== Checkout & grafik aktivitas harian =====
  /// Jam pekerja checkout (format HH:mm:ss), null kalau belum checkout.
  final String? jamCheckout;

  /// True kalau checkout ini dicatat OTOMATIS oleh sistem (lewat jam
  /// 17:10 tanpa pekerja menekan tombol Checkout), false kalau ditekan
  /// manual oleh pekerja.
  final bool checkoutOtomatis;

  /// Ringkasan aktivitas harian (menit di dalam/luar area, jumlah kali
  /// keluar area) -- diisi saat checkout, dipakai untuk grafik.
  final RingkasanAktivitas? ringkasan;

  RiwayatAbsensi({
    required this.id,
    required this.userId,
    required this.nama,
    required this.tanggal,
    required this.jam,
    required this.status,
    this.fotoBase64,
    this.keterangan,
    this.lat,
    this.lng,
    this.jamCheckout,
    this.checkoutOtomatis = false,
    this.ringkasan,
  });

  factory RiwayatAbsensi.fromMap(String id, Map<String, dynamic> data) {
    return RiwayatAbsensi(
      id: id,
      userId: data['userId'] ?? '',
      nama: data['nama'] ?? '',
      tanggal: data['tanggal'] ?? '',
      jam: data['jam'] ?? '',
      status: _statusFromString(data['status']),
      fotoBase64: data['foto'],
      keterangan: data['keterangan'],
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
      jamCheckout: data['jamCheckout'] as String?,
      checkoutOtomatis: data['checkoutOtomatis'] as bool? ?? false,
      ringkasan: data['ringkasanAktivitas'] == null
          ? null
          : RingkasanAktivitas.fromMap(data['ringkasanAktivitas'] as Map<String, dynamic>?),
    );
  }

  static StatusAbsensi _statusFromString(String? s) {
    switch (s) {
      case 'hadir':
        return StatusAbsensi.hadir;
      case 'telat':
        return StatusAbsensi.telat;
      case 'izin':
        return StatusAbsensi.izin;
      case 'sakit':
        return StatusAbsensi.sakit;
      case 'alpha':
        return StatusAbsensi.alpha;
      default:
        return StatusAbsensi.belum;
    }
  }
}

/// Helper tampilan (warna, ikon, label) untuk satu status, dipakai bareng
/// oleh halaman pekerja & pemilik supaya konsisten dan tidak duplikat
/// switch-case di banyak file.
(Color, IconData, String) infoStatusAbsensi(StatusAbsensi status) {
  switch (status) {
    case StatusAbsensi.hadir:
      return (Colors.green, Icons.check_circle, "Hadir");
    case StatusAbsensi.telat:
      return (Colors.orange, Icons.watch_later, "Telat");
    case StatusAbsensi.izin:
      return (Colors.blueGrey, Icons.event_busy, "Izin");
    case StatusAbsensi.sakit:
      return (Colors.redAccent, Icons.local_hospital, "Sakit");
    case StatusAbsensi.alpha:
      return (Colors.red.shade900, Icons.cancel, "Alpha");
    case StatusAbsensi.belum:
      return (Colors.grey, Icons.remove_circle_outline, "Belum Absen");
  }
}