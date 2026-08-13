// file: geofence_kebun.dart
//
// Data & helper untuk membatasi absensi Hadir hanya boleh dilakukan di
// dalam area kebun tertentu (geofencing sederhana berbasis polygon).
//
// Titik-titik di bawah adalah koordinat batas kebun (lat, lng) yang
// membentuk sebuah polygon tertutup. Urutan titik mengikuti keliling
// area (tidak masalah searah jarum jam atau sebaliknya -- algoritma
// ray-casting di bawah tetap valid untuk keduanya).

import 'package:latlong2/latlong.dart' as ll;

class GeofenceKebun {
  /// Titik-titik batas kebun. Urutan mengikuti keliling area.
  static final List<ll.LatLng> batasKebun = [
    ll.LatLng(3.556047, 98.686091),
    ll.LatLng(3.556040, 98.688470),
    ll.LatLng(3.557449, 98.688527),
    ll.LatLng(3.557511, 98.688121),
    ll.LatLng(3.557154, 98.688068),
    ll.LatLng(3.557151, 98.686988),
    ll.LatLng(3.556764, 98.686856),
    ll.LatLng(3.556474, 98.686813),
    ll.LatLng(3.556469, 98.686065),
  ];

  /// Cek apakah titik (lat, lng) berada di DALAM polygon [batasKebun],
  /// menggunakan algoritma ray-casting standar.
  ///
  /// Catatan: ini pengecekan polygon planar sederhana (menganggap bumi
  /// datar di area sekecil ini). Cukup akurat untuk area seluas kebun
  /// (skala puluhan-ratusan meter) dan sangat ringan secara komputasi,
  /// jadi aman dipanggil langsung di UI thread tanpa async.
  static bool isInside(double lat, double lng) {
    final polygon = batasKebun;
    if (polygon.length < 3) return true; // polygon tidak valid, jangan blokir

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      final intersect = ((yi > lng) != (yj > lng)) &&
          (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;

      j = i;
    }

    return inside;
  }
}