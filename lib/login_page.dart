import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard.dart';
import 'user_session.dart';
import 'deep_link_service.dart';
import 'absensi_pekerja.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool showPassword = false;
  bool loading = false;

  // Diisi setelah cekUsername() berhasil menemukan akun lewat
  // username_index, dipakai pas cekPassword().
  String? _loginEmail;
  String? _userId;
  bool _isAdminLogin = false;

  void snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _normalisasi(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  // Dipanggil di SEMUA jalur login sukses (Google, manual). Kalau halaman
  // ini dibuka gara-gara user tap link undangan absensi (dan sebelumnya
  // belum login), lanjut otomatis ke proses join room; kalau tidak,
  // seperti biasa ke Dashboard.
  //
  // PENTING: Dashboard tetap dipasang sebagai dasar navigation stack
  // (pushReplacement) SEBELUM AbsensiPekerjaPage ditumpuk di atasnya
  // (push biasa) -- kalau tidak, tombol back hilang setelah proses absen.
  void masukDashboard() {
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

  // ================= GOOGLE LOGIN =================
  Future<void> signInWithGoogle() async {
    setState(() => loading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        signInOption: SignInOption.standard,
      );

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser =
          await googleSignIn.signIn().timeout(const Duration(seconds: 30));

      if (googleUser == null) {
        snack('Login Google dibatalkan');
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? accessToken = googleAuth.accessToken;
      final String? idToken = googleAuth.idToken;

      if (accessToken == null && idToken == null) {
        throw Exception(
            'Tidak dapat mengambil token autentikasi dari Google. Pastikan Google Sign-In dikonfigurasi dengan benar di Firebase Console.');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-credential') {
          await googleSignIn.signOut();
          final GoogleSignInAccount? freshUser = await googleSignIn.signIn();
          if (freshUser != null) {
            final GoogleSignInAuthentication freshAuth = await freshUser.authentication;
            final OAuthCredential freshCredential = GoogleAuthProvider.credential(
              accessToken: freshAuth.accessToken,
              idToken: freshAuth.idToken,
            );
            userCredential = await FirebaseAuth.instance.signInWithCredential(freshCredential);
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final User user = userCredential.user!;

      final DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final DocumentSnapshot doc = await userRef.get();

      if (!doc.exists) {
        await userRef.set({
          'nama': user.displayName ?? 'User',
          'email': user.email ?? '',
          'bio': '',
          'telp': '',
          'fotoBase64': '',
          'fotoGoogleUrl': user.photoURL ?? '',
          'hasPassword': false,
          'loginMethod': 'google',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        await userRef.update({'lastLogin': FieldValue.serverTimestamp()});
      }

      final DocumentSnapshot updatedDoc = await userRef.get();
      final Map<String, dynamic> data = updatedDoc.data() as Map<String, dynamic>;

      UserSession.userId = userRef.id;
      UserSession.nama = data['nama'] ?? user.displayName ?? 'User';
      UserSession.role = 'user';
      UserSession.bio = data['bio'] ?? '';
      UserSession.telp = data['telp'] ?? '';
      UserSession.fotoBase64 = data['fotoBase64'] ?? '';
      UserSession.fotoGoogleUrl = user.photoURL ?? data['fotoGoogleUrl'] ?? '';
      UserSession.hasPassword = data['hasPassword'] ?? false;
      UserSession.isGoogleUser = true;

      masukDashboard();
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login Google gagal';
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'Akun sudah ada dengan metode login berbeda. Silakan coba login dengan metode lain.';
          break;
        case 'invalid-credential':
          errorMessage = 'Kredensial Google tidak valid. Pastikan Google Sign-In diaktifkan di Firebase Console dan OAuth Client dikonfigurasi dengan benar.';
          break;
        case 'user-disabled':
          errorMessage = 'Akun pengguna dinonaktifkan. Hubungi administrator.';
          break;
        case 'network-request-failed':
          errorMessage = 'Koneksi internet gagal. Periksa koneksi Anda dan coba lagi.';
          break;
        case 'too-many-requests':
          errorMessage = 'Terlalu banyak permintaan. Silakan coba lagi dalam beberapa menit.';
          break;
        default:
          errorMessage = 'Login Google gagal: ${e.message}';
      }
      snack(errorMessage);
    } on TimeoutException {
      snack('Login Google timeout. Periksa koneksi internet dan coba lagi.');
    } catch (e) {
      snack('Login Google gagal: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // ================= LOGIN MANUAL (CEK USERNAME) =================
  // Perubahan penting: TIDAK lagi baca field `password` dari Firestore.
  // Lookup ini cuma baca collection `username_index`, yang isinya cuma
  // {uid, loginEmail, isAdmin} -- boleh dibaca publik dengan aman karena
  // tidak ada data sensitif di dalamnya sama sekali.
  Future<void> cekUsername() async {
    final input = usernameController.text.trim();
    if (input.isEmpty) {
      snack('Isi username');
      return;
    }

    setState(() => loading = true);
    try {
      final key = _normalisasi(input);
      final doc = await FirebaseFirestore.instance.collection('username_index').doc(key).get();

      if (!doc.exists) {
        snack('Akun tidak ditemukan');
        setState(() => loading = false);
        return;
      }

      final data = doc.data()!;
      _loginEmail = data['loginEmail'] as String?;
      _userId = data['uid'] as String?;
      _isAdminLogin = data['isAdmin'] as bool? ?? false;

      if (_loginEmail == null || _userId == null) {
        snack('Akun ini belum bisa login manual, hubungi admin.');
        setState(() => loading = false);
        return;
      }

      setState(() {
        showPassword = true;
        loading = false;
      });
    } catch (e) {
      snack('Terjadi kesalahan');
      setState(() => loading = false);
    }
  }

  // ================= LOGIN MANUAL (VERIFIKASI PASSWORD) =================
  // Verifikasi password sepenuhnya ditangani Firebase Auth (client SDK,
  // gratis di plan Spark) -- password tidak pernah dibandingkan atau
  // dibaca dari Firestore.
  Future<void> cekPassword() async {
    final password = passwordController.text.trim();
    if (password.isEmpty) {
      snack('Password kosong');
      return;
    }
    if (_loginEmail == null || _userId == null) {
      snack('Sesi pencarian akun kadaluarsa, ulangi dari awal');
      setState(() => showPassword = false);
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmail!,
        password: password,
      );

      final doc = await FirebaseFirestore.instance
          .collection(_isAdminLogin ? 'admin' : 'users')
          .doc(_userId!)
          .get();
      final data = doc.data() ?? {};

      UserSession.userId = _userId!;
      UserSession.nama = _isAdminLogin ? 'Admin' : (data['nama'] ?? 'User');
      UserSession.role = _isAdminLogin ? 'admin' : 'user';
      UserSession.bio = data['bio'] ?? '';
      UserSession.telp = data['telp'] ?? '';
      UserSession.fotoBase64 = data['fotoBase64'] ?? '';
      UserSession.fotoGoogleUrl = data['fotoGoogleUrl'] ?? '';
      UserSession.hasPassword = true;
      UserSession.isGoogleUser = false;

      masukDashboard();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          snack('Password salah');
          break;
        case 'user-disabled':
          snack('Akun dinonaktifkan. Hubungi administrator.');
          break;
        case 'too-many-requests':
          snack('Terlalu banyak percobaan. Coba lagi nanti.');
          break;
        default:
          snack('Login gagal: ${e.message}');
      }
    } catch (e) {
      snack('Terjadi kesalahan login');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const SizedBox(height: 60),
                        Image.asset('assets/images/logo.png', height: 100),
                        const SizedBox(height: 10),
                        const Text(
                          "KAWAL KEBUN",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: loading ? null : signInWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('assets/images/google.jpg', height: 20),
                                const SizedBox(width: 12),
                                const Text("Masuk dengan Google", style: TextStyle(color: Colors.black)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => snack("Fungsi nomor HP belum aktif"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.phone, color: Colors.black),
                                SizedBox(width: 12),
                                Text("Masuk dengan Nomor HP", style: TextStyle(color: Colors.black)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Row(
                          children: [
                            Expanded(child: Divider(thickness: 1)),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("atau")),
                            Expanded(child: Divider(thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            hintText: "Username",
                            prefixIcon: const Icon(Icons.person),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        if (showPassword) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: "Password",
                              prefixIcon: const Icon(Icons.lock),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: loading ? null : (showPassword ? cekPassword : cekUsername),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              showPassword ? "Masuk" : "Lanjutkan",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}