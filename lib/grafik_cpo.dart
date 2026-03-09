import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GrafikCPOPage extends StatefulWidget {
  const GrafikCPOPage({super.key});

  @override
  State<GrafikCPOPage> createState() => _GrafikCPOPageState();
}

class _GrafikCPOPageState extends State<GrafikCPOPage> {
  int? selectedYear;
  final formatRupiah = NumberFormat("#,##0", "id_ID");

  String _getMonthLabel(int bulan) {
    const bulanList = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'
    ];
    return bulanList[bulan - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafik CPO International'),
        backgroundColor: Colors.green,
        centerTitle: true,
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
            return const Center(
              child: Text("Belum ada data CPO"),
            );
          }

          /// Ambil semua tahun unik
          final years = docs
              .map((e) => (e.data() as Map<String, dynamic>)['tahun'] as int)
              .toSet()
              .toList()
            ..sort();

          selectedYear ??= years.last;

          /// Filter sesuai tahun dipilih
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['tahun'] == selectedYear;
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text("Tidak ada data di tahun ini"),
            );
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

          // Tambahkan margin ±10%
          double margin = (maxHarga - minHarga) * 0.1;
          double adjustedMinY = (minHarga - margin).clamp(0, minHarga);
          double adjustedMaxY = maxHarga + margin;

          // Hitung interval otomatis agar angka tidak bertumpuk
          double range = adjustedMaxY - adjustedMinY;
          double interval = (range / 6).ceilToDouble(); // maksimal 6 angka di sisi kiri
          if (interval < 1) interval = 1;

          // Sesuaikan minY/maxY supaya rapi
          adjustedMinY = (adjustedMinY / interval).floor() * interval;
          adjustedMaxY = (adjustedMaxY / interval).ceil() * interval;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                /// DROPDOWN
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
                  height: 300, // tinggi grafik bisa disesuaikan
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
                              // Tampilkan angka utuh, sesuai interval
                              if ((value - adjustedMinY) % interval != 0) {
                                return const SizedBox();
                              }
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
                                return Text(
                                  _getMonthLabel(bulan),
                                  style: const TextStyle(fontSize: 10),
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