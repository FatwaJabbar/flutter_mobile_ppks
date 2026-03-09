import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'analisa_kebun.dart';
import 'riwayat.dart';
import 'akun1.dart';
import 'database_helper.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  double totalPendapatan = 0;
  double totalPengeluaran = 0;
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  // Simulasi daftar kebun (bisa diganti dengan query DB masing-masing kebun)
  List<Map<String, dynamic>> daftarKebun = [
    {'nama': 'Kebun A', 'lokasi': 'Desa A'},
    {'nama': 'Kebun B', 'lokasi': 'Desa B'},
  ];

  Map<String, Map<String, double>> kebunTotals = {};

  @override
  void initState() {
    super.initState();
    _hitungPendapatan();
  }

  Future<void> _hitungPendapatan() async {
    final data = await DBHelper.getAll();

    double pendapatan = 0;
    double pengeluaran = 0;
    Map<String, Map<String, double>> tempKebunTotals = {};

    for (var item in data) {
      final type = (item['type'] ?? '').toString().toLowerCase().trim();
      final berat = (item['berat'] ?? 0).toDouble();
      final harga = (item['harga'] ?? 0).toDouble();
      final biaya = (item['biaya'] ?? 0).toDouble();
      final lainnya = (item['lainnya'] ?? 0).toDouble();
      final totalBiaya = biaya + lainnya;

      // Asumsi ada field kebun untuk tiap item
      final kebunName = (item['kebun'] ?? 'Umum').toString();

      if (!tempKebunTotals.containsKey(kebunName)) {
        tempKebunTotals[kebunName] = {
          'pendapatan': 0,
          'pengeluaran': 0,
        };
      }

      if (type == 'panen') {
        pendapatan += berat * harga;
        tempKebunTotals[kebunName]!['pendapatan'] =
            tempKebunTotals[kebunName]!['pendapatan']! + (berat * harga);
      } else {
        pengeluaran += totalBiaya;
        tempKebunTotals[kebunName]!['pengeluaran'] =
            tempKebunTotals[kebunName]!['pengeluaran']! + totalBiaya;
      }
    }

    setState(() {
      totalPendapatan = pendapatan;
      totalPengeluaran = pengeluaran;
      kebunTotals = tempKebunTotals;
    });
  }

  double get pendapatanBersih => totalPendapatan - totalPengeluaran;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC94A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00994D),
        title: const Text(
          'Laporan',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 5,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RiwayatPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AccountPage1()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Kartu Analisa Kebun
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: ListTile(
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bar_chart, color: Colors.purple),
                ),
                title: const Text(
                  "Analisa Kebun",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text("Rincian Performa Kebun Anda"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalisaKebunPage(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // 🔹 Kartu Pendapatan Bersih
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    const Text(
                      "Pendapatan Bersih Anda",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Rp ${_formatter.format(pendapatanBersih)}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Divider(thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Pendapatan"),
                        Text("Rp ${_formatter.format(totalPendapatan)}"),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Pengeluaran"),
                        Text("Rp ${_formatter.format(totalPengeluaran)}"),
                      ],
                    ),
                  ],
                ),
              ),
            ),



            // 🔹 Kartu Daftar Kebun

          ],
        ),
      ),
    );
  }
}