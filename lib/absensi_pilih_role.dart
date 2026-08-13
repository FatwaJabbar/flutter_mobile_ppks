// file: absensi_pilih_role.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'absensi_service.dart';
import 'absensi_pemilik.dart';
import 'absensi_pekerja.dart';
import 'user_session.dart';

class AbsensiPilihRolePage extends StatefulWidget {
  const AbsensiPilihRolePage({super.key});

  @override
  State<AbsensiPilihRolePage> createState() => _AbsensiPilihRolePageState();
}

class _AbsensiPilihRolePageState extends State<AbsensiPilihRolePage> {
  bool _mengecek = true;

  @override
  void initState() {
    super.initState();
    _cekStatusAwal();
  }

  Future<void> _cekStatusAwal() async {
    final uid = UserSession.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _mengecek = false);
      return;
    }

    // Kalau user sudah punya room sebagai pemilik -> langsung masuk
    final roomPemilik = await AbsensiService.getRoomByOwner(uid);
    if (roomPemilik != null) {
      _bukaPemilik();
      return;
    }

    // Kalau user sudah tergabung sebagai pekerja -> langsung masuk
    final roomId = await AbsensiService.getMyRoomId(uid);
    if (roomId != null && roomId.isNotEmpty) {
      _bukaPekerja();
      return;
    }

    setState(() => _mengecek = false);
  }

  void _bukaPemilik() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AbsensiPemilikPage()),
    );
  }

  void _bukaPekerja() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AbsensiPekerjaPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mengecek) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8E1),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Absensi", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 90, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              "Pilih peran Anda untuk melanjutkan",
              style: TextStyle(fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            _kartuRole(
              icon: Icons.workspace_premium,
              judul: "Pemilik",
              deskripsi: "Buat ruang absensi & pantau kehadiran pekerja",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AbsensiPemilikPage()),
              ),
            ),
            const SizedBox(height: 16),
            _kartuRole(
              icon: Icons.badge_outlined,
              judul: "Pekerja",
              deskripsi: "Gabung ruang absensi menggunakan kode akses",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AbsensiPekerjaPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuRole({
    required IconData icon,
    required String judul,
    required String deskripsi,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.green),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(deskripsi, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }
}