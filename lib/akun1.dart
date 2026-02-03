// file: akun1.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'editprofil1.dart';
import 'login_page.dart';
import 'katasandi1.dart';
import 'aktivitas.dart';
import 'tambahpanen.dart';
import 'user_session.dart';

class AccountPage1 extends StatefulWidget {
  const AccountPage1({super.key});

  @override
  State<AccountPage1> createState() => _AccountPage1State();
}

class _AccountPage1State extends State<AccountPage1> {
  late String nama;
  late String bio;
  late String telp;
  Uint8List? fotoLocal;
  String? fotoGoogleUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    // Ambil data dari UserSession
    nama = UserSession.nama ?? 'User';
    bio = UserSession.bio ?? '';
    telp = UserSession.telp ?? '';
    fotoGoogleUrl = UserSession.fotoGoogleUrl;
    final fotoBase64 = UserSession.fotoBase64 ?? '';

    if (fotoBase64.isNotEmpty) {
      fotoLocal = base64Decode(fotoBase64);
    }
    setState(() {});
  }

  // ================= LOGOUT FINAL =================
  Future<void> _logout(BuildContext context) async {
    final googleSignIn = GoogleSignIn();

    try {
      // Logout dari Firebase
      await FirebaseAuth.instance.signOut();

      // Logout Google hanya jika user login Google
      if (UserSession.isGoogleUser) {
        await googleSignIn.signOut();
      }

      // Bersihkan session
      UserSession.clear();

      if (!mounted) return;

      // Navigasi ke halaman login, tidak bisa kembali
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal logout: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider avatar;
    if (fotoLocal != null && fotoLocal!.isNotEmpty) {
      avatar = MemoryImage(fotoLocal!);
    } else if (fotoGoogleUrl != null && fotoGoogleUrl!.isNotEmpty) {
      avatar = NetworkImage(fotoGoogleUrl!);
    } else {
      avatar = const AssetImage('assets/images/default_avatar.png');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          "Akun Saya",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFE082), Color(0xFFFFC107)],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(radius: 45, backgroundImage: avatar),
                  const SizedBox(height: 10),
                  Text(
                    nama,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(bio),
                  Text("Telp: $telp"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfilPage(),
                        ),
                      );
                      if (result == true) {
                        _loadProfile();
                      }
                    },
                    child: const Text("Edit Profil"),
                  ),
                ],
              ),
            ),
            _menu(
              Icons.add_circle_outline,
              "Tambahkan Panen",
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TambahPanenPage(),
                  ),
                );
              },
            ),
            _menu(
              Icons.history,
              "Riwayat Aktivitas",
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AktivitasPage(),
                  ),
                );
              },
            ),
            // Hanya tampilkan "Kata Sandi" untuk login manual
            if (!UserSession.isGoogleUser)
              _menu(
                Icons.lock_outline,
                "Kata Sandi",
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const KataSandi1(),
                    ),
                  );
                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Password berhasil diubah")),
                    );
                  }
                },
              ),
            _menu(
              Icons.logout,
              "Keluar",
              () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(text),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8E1),
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            child: const Text("Keluar"),
          ),
        ],
      ),
    );
  }
}
