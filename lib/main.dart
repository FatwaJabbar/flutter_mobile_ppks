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

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ❌ HAPUS ATAU KOMENTAR BARIS INI:
  // await FirebaseAuth.instance.signOut(); 

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

          // Langsung ke Dashboard
          if (mounted) {
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