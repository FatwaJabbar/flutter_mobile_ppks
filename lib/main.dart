import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Tambahkan ini
import 'firebase_options.dart';
import 'login_page.dart';
import 'dashboard.dart'; // Import Dashboard
import 'user_session.dart'; // Import Session
import 'deep_link_service.dart'; // Tambahan: penangan link undangan absensi
import 'absensi_pekerja.dart';
import 'absensi_background_service.dart'; // Tambahan: lanjutkan tracking lokasi kalau masih aktif

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

// GlobalKey navigator supaya DeepLinkService bisa navigasi dari mana saja
// tanpa butuh BuildContext dari widget tertentu.
final navigatorKey = GlobalKey<NavigatorState>();


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling for duplicate app
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase app already exists, ignore error
    if (e.toString().contains('duplicate-app')) {
      print('Firebase app already initialized');
    } else {
      rethrow;
    }
  }

  // ❌ HAPUS ATAU KOMENTAR BARIS INI:
  // await FirebaseAuth.instance.signOut();

  // Kalau proses Dart sebelumnya mati total (mis. OS bersih-bersih memori)
  // sementara pekerja masih berstatus "sudah Hadir belum Checkout", service
  // tracking lokasi latar belakang dilanjutkan lagi di sini.
  await AbsensiBackgroundService.lanjutkanJikaMasihAktif();

  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Mulai dengarkan link undangan absensi (ppks://gabung?kode=...
    // atau https://.../gabung?kode=...)
    DeepLinkService.init(navigatorKey);
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // <-- WAJIB supaya DeepLinkService bisa jalan
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      home: const TampilanAwal(),
    );
  }
}

class TampilanAwal extends StatefulWidget {
  const TampilanAwal({super.key});

  @override
  State<TampilanAwal> createState() => _TampilanAwalState();
}

class _TampilanAwalState extends State<TampilanAwal> {
  @override
  void initState() {
    super.initState();
    _pindahHalaman();
  }

  // Logika pengecekan login di Splash Screen
  Future<void> _pindahHalaman() async {
    await Future.delayed(const Duration(seconds: 3));

    // 1. Cek apakah ada user yang masih tersimpan sesinya di Firebase
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // 2. Jika ada, ambil data dari Firestore untuk mengisi UserSession
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (doc.exists) {
          final data = doc.data()!;
          UserSession.userId = doc.id;
          UserSession.nama = data['nama'] ?? user.displayName ?? 'User';
          UserSession.role = 'user';
          UserSession.bio = data['bio'] ?? '';
          UserSession.telp = data['telp'] ?? '';
          UserSession.fotoBase64 = data['fotoBase64'] ?? '';
          UserSession.fotoGoogleUrl = user.photoURL ?? data['fotoGoogleUrl'] ?? '';
          UserSession.hasPassword = data['hasPassword'] ?? false;
          UserSession.isGoogleUser = true;

          if (mounted) {
            // Kalau splash screen ini dibuka karena user tap link undangan
            // absensi (dan ternyata sudah login), lanjut ke room absensi --
            // TAPI Dashboard tetap dipasang sebagai dasar stack (bukan
            // pushReplacement langsung ke AbsensiPekerjaPage), supaya ada
            // jalan navigasi "back" ke Dashboard setelah proses absen
            // selesai. Tanpa ini, AbsensiPekerjaPage jadi route paling
            // dasar (canPop() == false, tidak ada tombol back di AppBar)
            // dan pengguna tidak akan pernah bisa kembali ke Dashboard.
            if (DeepLinkService.pendingKode != null) {
              final kode = DeepLinkService.pendingKode!;
              DeepLinkService.pendingKode = null;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AbsensiPekerjaPage(kodeAwal: kode)),
              );
              return;
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint("Gagal mengambil data sesi: $e");
      }
    }

    // 3. Jika tidak ada user atau error, baru ke LoginPage
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 250),
            const SizedBox(height: 8),
            const Text(
              'KAWAL\nKEBUN',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF004D40),
                letterSpacing: 1.5,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}