import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'akun1.dart';
import 'catatpanen.dart';
import 'dokumentasi.dart';
import 'grafik_cpo.dart';
import 'grafik_tbs.dart';
import 'laporan.dart';
import 'sewa_agronomis.dart';
import 'catatrawat.dart';
import 'daftar_kebun.dart';
import 'pengawal.dart';
import 'riwayat.dart';
import 'user_session.dart'; // ⭐ USER SESSION

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardContent(),
    const RiwayatPage(),
    const AccountPage1(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    // ===================== AMBIL DATA USER =====================
    String displayName = 'User';
    ImageProvider avatar = const AssetImage('assets/images/@jimmyyjp.jpg');

    if (UserSession.nama != null) {
      displayName = UserSession.nama!;
      if ((UserSession.fotoBase64 ?? '').isNotEmpty) {
        avatar = MemoryImage(base64Decode(UserSession.fotoBase64!));
      } else if ((UserSession.fotoGoogleUrl ?? '').isNotEmpty) {
        avatar = NetworkImage(UserSession.fotoGoogleUrl!);
      }
    } else {
      // Login Google fallback
      final user = FirebaseAuth.instance.currentUser;
      displayName = user?.displayName ?? 'User';
      if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
        avatar = NetworkImage(user.photoURL!);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ================= HEADER ==================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(color: Colors.green),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AccountPage1()),
                        );
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: avatar,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Halo, $displayName",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.notifications_none, color: Colors.white),
                  ],
                ),
              ),

              // ================= ISI DASHBOARD ==================
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFE082), Color(0xFFFFC107)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==== INFO BOX ====
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GrafikCPOPage()),
                                );
                              },
                              child: _infoCard("CPO International", "Rp.", "Tanggal"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GrafikTBSPage()),
                                );
                              },
                              child: _infoCard("Harga TBS Disbun Riau", "Rp.", "Tanggal"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ==== CATAT KEGIATAN KEBUN ====
                      _sectionTitle("Catat Kegiatan Kebun"),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE59D), Color(0xFFFFB347)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _menuItem(Icons.nature, "Kebun Saya", onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DaftarKebunPage()),
                              );
                            }),
                            _menuItem(Icons.agriculture, "Panen", onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CatatPanenPage()),
                              );
                            }),
                            _menuItem(Icons.grass, "Rawat", onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CatatRawatPage()),
                              );
                            }),
                            _menuItem(Icons.camera_alt, "Dokumentasi", onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DokumentasiPage()),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ==== PRODUKTIVITAS ====
                      _sectionTitle("Tingkatkan Produktivitas"),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE59D), Color(0xFFFFB347)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _menuItem(Icons.local_florist, "Pengawal Sawit", onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PengawalPage()),
                              );
                            }),
                            _menuItem(Icons.engineering, "Sewa Agronomis", onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SewaAgronomisPage()),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ==== LAPORAN ====
                      _sectionTitle("Laporan Kebun:"),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Pendapatan Bersih",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _textRow("Total Pendapatan", "Rp."),
                            _textRow("Total Pengeluaran", "Rp."),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LaporanPage()),
                                  );
                                },
                                child: const Text("Lihat Detail"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== WIDGET BANTUAN ==========================
  static Widget _infoCard(String title, String price, String date) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(color: Colors.red, fontSize: 13)),
          const SizedBox(height: 6),
          Text(date, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }

  static Widget _menuItem(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.orange, size: 35),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  static Widget _textRow(String left, String right) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: const TextStyle(fontSize: 14)),
        Text(right, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
