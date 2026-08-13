import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'absensi_pekerja.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Kode akses yang sedang menunggu diproses. Dipakai HANYA untuk kasus
  /// cold start / belum login, dibaca & di-set null lagi oleh
  /// TampilanAwal (main.dart) atau LoginPage.
  static String? pendingKode;

  static void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    // Kalau app dibuka pertama kali LEWAT link (app belum jalan sama sekali)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _tangani(uri);
    });

    // Kalau app SUDAH JALAN (foreground/background) lalu link ditekan
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _tangani(uri);
    });
  }

  static void dispose() {
    _sub?.cancel();
  }

  static void _tangani(Uri uri) {
    if (uri.scheme != 'ppks' || uri.host != 'gabung') return;

    final kode = uri.queryParameters['kode'];
    if (kode == null || kode.isEmpty) return;

    final sudahLogin = FirebaseAuth.instance.currentUser != null;
    final navState = _navigatorKey?.currentState;

    if (sudahLogin && navState != null) {
      // App sudah jalan & user sudah login -> tumpuk langsung halaman
      // Absensi di atas apa pun yang lagi dibuka sekarang (Dashboard, dll),
      // tanpa nunggu splash/login karena keduanya sudah tidak akan dibuka lagi.
      navState.push(
        MaterialPageRoute(builder: (_) => AbsensiPekerjaPage(kodeAwal: kode)),
      );
      debugPrint('DeepLinkService: langsung push AbsensiPekerjaPage -> $kode');
    } else {
      // Belum login, atau ini cold start (navigator belum pasti siap) ->
      // simpan dulu, biar splash/login yang proses setelah UserSession terisi.
      pendingKode = kode;
      debugPrint('DeepLinkService: kode disimpan (pending) -> $kode');
    }
  }

  static const String _bridgeUrl =
      'https://script.google.com/macros/s/AKfycbyrXudEQfWCRq0Juh9qAx4cWymJPyot_cLQuRnXsfrgdpSJ3w0-Mt9ahjjkbga4XzazPw/exec';

  static String buatLink(String kodeAkses) {
    return '$_bridgeUrl?kode=$kodeAkses';
  }
}