import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'akun1.dart';
import 'catatpanen.dart';
import 'dokumentasi.dart';
import 'grafik_cpo.dart';
import 'grafik_tbs.dart';
import 'laporan.dart';
// import 'sewa_agronomis.dart';
import 'catatrawat.dart';
import 'daftar_kebun.dart';
// import 'pengawal.dart';
import 'riwayat.dart';
import 'user_session.dart';
import 'database_helper.dart'; // buat ambil total pengeluaran/pemasukan
import 'package:intl/intl.dart';
import 'absensi_pilih_role.dart';

class DashboardPage extends StatefulWidget {
  final int initialIndex;

  const DashboardPage({super.key, this.initialIndex = 0});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late int _selectedIndex;

  final List<Widget> _pages = [
    const DashboardContent(),
    const RiwayatPage(),
    const AccountPage1(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
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

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  double totalPendapatan = 0;
  double totalPengeluaran = 0;
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  // FILTER
  String _selectedJenis = 'Semua Jenis';
  String _selectedTanggal = 'Semua Tanggal';
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DBHelper.getAll(); // ambil semua data
    setState(() => _data = data);
    _applyFilter();
  }

  void _applyTanggalFilter() {
    final now = DateTime.now();
    if (_selectedTanggal == 'Hari Ini') {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedTanggal == 'Minggu Ini') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      _startDate = DateTime(monday.year, monday.month, monday.day);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedTanggal == 'Bulan Ini') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedTanggal == 'Tahun Ini') {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else {
      _startDate = null;
      _endDate = null;
    }
  }

  DateTime? _parseTanggal(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }

  void _applyFilter() {
    _applyTanggalFilter();
    double pendapatan = 0;
    double pengeluaran = 0;

    for (var item in _data) {
      final type = (item['type'] ?? '').toString().toLowerCase();

      // Filter jenis
      if (_selectedJenis != 'Semua Jenis' &&
          type != _selectedJenis.toLowerCase()) continue;

      // Filter tanggal
      final tgl = _parseTanggal(item['tanggal']);
      if (_startDate != null && _endDate != null) {
        if (tgl == null || tgl.isBefore(_startDate!) || tgl.isAfter(_endDate!)) continue;
      }

      final berat = (item['berat'] ?? 0).toDouble();
      final harga = (item['harga'] ?? 0).toDouble();
      final biaya = (item['biaya'] ?? 0).toDouble();
      final lainnya = (item['lainnya'] ?? 0).toDouble();
      final totalBiaya = biaya + lainnya;

      if (type == 'panen') {
        pendapatan += berat * harga;
      } else {
        pengeluaran += totalBiaya;
      }
    }

    setState(() {
      totalPendapatan = pendapatan;
      totalPengeluaran = pengeluaran;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              // Header
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
                      // Info Cards
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
                              child: _infoCard("Harga TBS", "Rp.", "Tanggal"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _sectionTitle("Catat Kegiatan Kebun"),
                      // Kegiatan Grid
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

                      // ================= WIDGET ABSENSI (BARU) =================
                      _sectionTitle("Absensi"),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AbsensiPilihRolePage()),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE59D), Color(0xFFFFB347)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black26),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Icon(Icons.fingerprint, color: Colors.green, size: 26),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Absensi Menu",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      "Kelola & catat kehadiran dengan verifikasi wajah",
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ================= AKHIR WIDGET ABSENSI =================

                      // _sectionTitle("Tingkatkan Produktivitas"),
                      // // Produktivitas Grid
                      // Container(
                      //   padding: const EdgeInsets.all(10),
                      //   decoration: BoxDecoration(
                      //     gradient: const LinearGradient(
                      //       colors: [Color(0xFFFFE59D), Color(0xFFFFB347)],
                      //       begin: Alignment.topLeft,
                      //       end: Alignment.bottomRight,
                      //     ),
                      //     borderRadius: BorderRadius.circular(8),
                      //     border: Border.all(color: Colors.black26),
                      //   ),
                      //   child: GridView.count(
                      //     crossAxisCount: 2,
                      //     crossAxisSpacing: 10,
                      //     mainAxisSpacing: 10,
                      //     shrinkWrap: true,
                      //     physics: const NeverScrollableScrollPhysics(),
                      //     children: [
                      //       _menuItem(Icons.local_florist, "Pengawal Sawit", onTap: () {
                      //         Navigator.push(
                      //           context,
                      //           MaterialPageRoute(builder: (_) => const PengawalPage()),
                      //         );
                      //       }),
                      //       _menuItem(Icons.engineering, "Sewa Agronomis", onTap: () {
                      //         Navigator.push(
                      //           context,
                      //           MaterialPageRoute(builder: (_) => const SewaAgronomisPage()),
                      //         );
                      //       }),
                      //     ],
                      //   ),
                      // ),
                      // const SizedBox(height: 20),

                      // Laporan Kebun dengan Filter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Laporan Kebun",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 8),
                              _filterDropdownTanggal(),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                            _textRow("Total Pendapatan", "Rp ${_formatter.format(totalPendapatan)}"),
                            _textRow("Total Pengeluaran", "Rp ${_formatter.format(totalPengeluaran)}"),
                            _textRow(
                                "Pendapatan Bersih", "Rp ${_formatter.format(totalPendapatan - totalPengeluaran)}"),
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

  // Dropdown Filter Jenis

  // Dropdown Filter Tanggal
  Widget _filterDropdownTanggal() {
    final tanggalList = ['Semua Tanggal', 'Hari Ini', 'Minggu Ini', 'Bulan Ini', 'Tahun Ini'];
    return DropdownButton<String>(
      value: _selectedTanggal,
      items: tanggalList
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _selectedTanggal = v;
          _applyFilter();
        });
      },
    );
  }

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