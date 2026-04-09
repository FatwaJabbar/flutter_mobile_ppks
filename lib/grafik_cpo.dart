import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_session.dart';

class GrafikCPOPage extends StatefulWidget {
  const GrafikCPOPage({super.key});

  @override
  State<GrafikCPOPage> createState() => _GrafikCPOPageState();
}

class _GrafikCPOPageState extends State<GrafikCPOPage> {
  int? selectedYear;
  final formatRupiah = NumberFormat("#,##0", "id_ID");

  // Fungsi untuk mendapatkan nama bulan lengkap
  String _getMonthLabel(int bulan) {
    const bulanList = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return bulanList[bulan - 1];
  }

  void _showAddDataDialog() {
    final TextEditingController yearController = TextEditingController(text: "2026");
    final TextEditingController priceController = TextEditingController();
    int selectedMonth = 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah Data CPO"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: yearController,
                decoration: const InputDecoration(labelText: "Tahun"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: selectedMonth,
                decoration: const InputDecoration(labelText: "Bulan"),
                items: List.generate(12, (index) => index + 1).map((m) {
                  return DropdownMenuItem(
                    value: m, 
                    child: Text(_getMonthLabel(m)), // Menggunakan nama bulan lengkap
                  );
                }).toList(),
                onChanged: (val) => selectedMonth = val!,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: "Harga (CPO)"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (yearController.text.isNotEmpty && priceController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('cpo_international').add({
                  'tahun': int.parse(yearController.text),
                  'bulan': selectedMonth,
                  'harga': double.parse(priceController.text),
                });
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafik CPO International'),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          if (UserSession.role == 'admin') 
            IconButton(
              icon: const Icon(Icons.add_chart),
              onPressed: _showAddDataDialog,
              tooltip: "Tambah Data",
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cpo_international')
            .orderBy('tahun')
            .orderBy('bulan')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("Belum ada data CPO"));
          }

          final years = docs
              .map((e) => (e.data() as Map<String, dynamic>)['tahun'] as int)
              .toSet()
              .toList()
            ..sort();

          selectedYear ??= years.last;

          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['tahun'] == selectedYear;
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text("Tidak ada data di tahun ini"));
          }

          List<FlSpot> spots = [];
          List<double> hargaList = [];

          for (var doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final harga = (data['harga'] as num).toDouble();
            final bulan = data['bulan'];

            spots.add(FlSpot((bulan - 1).toDouble(), harga));
            hargaList.add(harga);
          }

          double minHarga = hargaList.reduce((a, b) => a < b ? a : b);
          double maxHarga = hargaList.reduce((a, b) => a > b ? a : b);
          double margin = (maxHarga - minHarga) * 0.1;
          if (margin == 0) margin = 100;

          double adjustedMinY = (minHarga - margin).clamp(0, minHarga);
          double adjustedMaxY = maxHarga + margin;

          double range = adjustedMaxY - adjustedMinY;
          double interval = (range / 6).ceilToDouble();
          if (interval < 1) interval = 1;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  items: years.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text("Tahun $year"),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedYear = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: LineChart(
                    LineChartData(
                      minY: adjustedMinY,
                      maxY: adjustedMaxY,
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: interval,
                      ),
                      borderData: FlBorderData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                formatRupiah.format(value.toInt()),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              int bulan = value.toInt() + 1;
                              if (bulan >= 1 && bulan <= 12) {
                                // Mengambil 3 huruf depan saja untuk tampilan sumbu X grafik 
                                // agar tidak terlalu sesak, tapi di dialog tetap full.
                                // Jika ingin di grafik juga full, hapus .substring(0, 3)
                                String label = _getMonthLabel(bulan);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    label.length > 3 ? label.substring(0, 3) : label,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.greenAccent.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}