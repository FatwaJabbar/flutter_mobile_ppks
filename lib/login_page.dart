import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard.dart';
import 'user_session.dart';

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
  String? userId;
  String? savedPassword;

  void snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void masukDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

  // ================= GOOGLE LOGIN =================
  Future<void> signInWithGoogle() async {
    setState(() => loading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      // PAKSA user pilih akun
      final googleUser = await googleSignIn.signInSilently();
      if (googleUser != null) {
        await googleSignIn.disconnect();
      }
      final selectedUser = await googleSignIn.signIn(); // Paksa pilih akun
      if (selectedUser == null) {
        snack('Login Google dibatalkan');
        setState(() => loading = false);
        return;
      }
      final googleAuth = await selectedUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await ref.get();

      // Auto-register jika user baru
      if (!doc.exists) {
        await ref.set({
          'nama': user.displayName ?? 'User',
          'email': user.email ?? '',
          'bio': '',
          'telp': '',
          'fotoBase64': '',
          'fotoGoogleUrl': user.photoURL ?? '',
          'hasPassword': false,
          'loginMethod': 'google',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final data = (await ref.get()).data()!;

      UserSession.userId = ref.id;
      UserSession.nama = data['nama'] ?? user.displayName ?? 'User';
      UserSession.bio = data['bio'] ?? '';
      UserSession.telp = data['telp'] ?? '';
      UserSession.fotoBase64 = data['fotoBase64'] ?? '';
      UserSession.fotoGoogleUrl = user.photoURL ?? data['fotoGoogleUrl'] ?? '';
      UserSession.hasPassword = data['hasPassword'] ?? false;
      UserSession.isGoogleUser = true;

      masukDashboard();
    } catch (e) {
      snack('Login Google gagal');
    } finally {
      setState(() => loading = false);
    }
  }

  // ================= USERNAME LOGIN =================
  Future<void> cekUsername() async {
    final username = usernameController.text.trim();
    if (username.isEmpty) {
      snack('Isi username');
      return;
    }

    setState(() => loading = true);
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('nama', isEqualTo: username)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        snack('Akun tidak ditemukan');
        setState(() => loading = false);
        return;
      }

      final doc = q.docs.first;
      userId = doc.id;
      final data = doc.data();
      savedPassword = (data['password'] ?? '').toString();

      setState(() {
        showPassword = savedPassword != null && savedPassword!.isNotEmpty;
        loading = false;
      });

      // Jika user belum pakai password, langsung login
      if (!showPassword) {
        UserSession.userId = doc.id;
        UserSession.nama = data['nama'] ?? 'User';
        UserSession.bio = data['bio'] ?? '';
        UserSession.telp = data['telp'] ?? '';
        UserSession.fotoBase64 = data['fotoBase64'] ?? '';
        UserSession.fotoGoogleUrl = data['fotoGoogleUrl'] ?? '';
        UserSession.hasPassword = false;
        UserSession.isGoogleUser = false;
        masukDashboard();
      }
    } catch (e) {
      snack('Terjadi kesalahan');
      setState(() => loading = false);
    }
  }

  Future<void> cekPassword() async {
    final password = passwordController.text.trim();
    if (password.isEmpty) {
      snack('Password kosong');
      return;
    }
    if (userId == null) {
      snack('User belum valid');
      return;
    }

    setState(() => loading = true);
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) {
        snack('User tidak ditemukan');
        setState(() => loading = false);
        return;
      }
      final data = doc.data();
      if ((data?['password'] ?? '').toString() != password) {
        snack('Password salah');
        setState(() => loading = false);
        return;
      }

      UserSession.userId = doc.id;
      UserSession.nama = data?['nama'] ?? 'User';
      UserSession.bio = data?['bio'] ?? '';
      UserSession.telp = data?['telp'] ?? '';
      UserSession.fotoBase64 = data?['fotoBase64'] ?? '';
      UserSession.fotoGoogleUrl = data?['fotoGoogleUrl'] ?? '';
      UserSession.hasPassword = true;
      UserSession.isGoogleUser = false;

      masukDashboard();
    } catch (e) {
      snack('Terjadi kesalahan login');
    } finally {
      setState(() => loading = false);
    }
  }

  // ================= UI =================
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

                        // GOOGLE LOGIN
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: loading ? null : signInWithGoogle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/google.jpg',
                                  height: 20,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Masuk dengan Google",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // LOGIN NO HP (placeholder)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              snack("Fungsi login nomor HP belum dibuat");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.phone, color: Colors.black),
                                SizedBox(width: 12),
                                Text(
                                  "Masuk dengan Nomor HP",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // DIVIDER
                        Row(
                          children: const [
                            Expanded(child: Divider(thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                "atau",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Masuk menggunakan akun yang sudah terdaftar",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // USERNAME
                        TextField(
                          controller: usernameController,
                          decoration: InputDecoration(
                            hintText: "Username",
                            prefixIcon: const Icon(Icons.person),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // BUTTON MASUK
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: loading
                                ? null
                                : showPassword
                                    ? cekPassword
                                    : cekUsername,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              showPassword ? "Masuk" : "Lanjutkan",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
