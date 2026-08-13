// file: absensi_aktivitas_models.dart
// Model tambahan untuk fitur Checkout + Grafik Aktivitas Harian.
// File ini BERDIRI SENDIRI (tidak menyentuh absensi_models.dart) supaya
// aman ditambahkan tanpa risiko merusak model yang sudah ada.
// Catatan: RiwayatAbsensi tetap perlu ditambah field `jamCheckout`,
// `checkoutOtomatis`, dan `ringkasanAktivitas` -- lihat instruksi patch
// yang menyertai file-file ini.

class LokasiCheckpoint {
  final DateTime waktu;
  final bool diDalamArea;
  final double lat;
  final double lng;

  LokasiCheckpoint({
    required this.waktu,
    required this.diDalamArea,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toMap() => {
        'waktu': waktu.toIso8601String(),
        'diDalamArea': diDalamArea,
        'lat': lat,
        'lng': lng,
      };

  factory LokasiCheckpoint.fromMap(Map<String, dynamic> m) => LokasiCheckpoint(
        waktu: DateTime.parse(m['waktu'] as String),
        diDalamArea: m['diDalamArea'] as bool? ?? false,
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
      );
}

/// Ringkasan aktivitas satu hari, dihitung dari seluruh [LokasiCheckpoint]
/// sejak absen Hadir sampai Checkout. Disimpan langsung di dokumen riwayat
/// absensi pekerja supaya grafik bisa ditampilkan tanpa menghitung ulang
/// setiap kali dibuka.
class RingkasanAktivitas {
  final int totalMenitDiDalam;
  final int totalMenitDiLuar;
  final int jumlahKeluarArea;
  final int totalCheckpoint;

  const RingkasanAktivitas({
    required this.totalMenitDiDalam,
    required this.totalMenitDiLuar,
    required this.jumlahKeluarArea,
    required this.totalCheckpoint,
  });

  factory RingkasanAktivitas.kosong() => const RingkasanAktivitas(
        totalMenitDiDalam: 0,
        totalMenitDiLuar: 0,
        jumlahKeluarArea: 0,
        totalCheckpoint: 0,
      );

  double get totalMenit => (totalMenitDiDalam + totalMenitDiLuar).toDouble();

  double get persenDiDalam => totalMenit == 0 ? 0 : (totalMenitDiDalam / totalMenit) * 100;
  double get persenDiLuar => totalMenit == 0 ? 0 : (totalMenitDiLuar / totalMenit) * 100;

  Map<String, dynamic> toMap() => {
        'totalMenitDiDalam': totalMenitDiDalam,
        'totalMenitDiLuar': totalMenitDiLuar,
        'jumlahKeluarArea': jumlahKeluarArea,
        'totalCheckpoint': totalCheckpoint,
      };

  factory RingkasanAktivitas.fromMap(Map<String, dynamic>? m) {
    if (m == null) return RingkasanAktivitas.kosong();
    return RingkasanAktivitas(
      totalMenitDiDalam: (m['totalMenitDiDalam'] as num?)?.toInt() ?? 0,
      totalMenitDiLuar: (m['totalMenitDiLuar'] as num?)?.toInt() ?? 0,
      jumlahKeluarArea: (m['jumlahKeluarArea'] as num?)?.toInt() ?? 0,
      totalCheckpoint: (m['totalCheckpoint'] as num?)?.toInt() ?? 0,
    );
  }
}