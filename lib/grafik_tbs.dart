import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GrafikTBSPage extends StatefulWidget {
  const GrafikTBSPage({super.key});

  @override
  State<GrafikTBSPage> createState() => _GrafikTBSPageState();
}

class _GrafikTBSPageState extends State<GrafikTBSPage> {
  String selectedProvinsi = "Semua";
  int tahunAwal = 2026;
  int tahunAkhir = 2026;

  List<String> provinsiList = ["Semua"];
  late Future<List<QueryDocumentSnapshot>> _futureData;

  final formatRupiah = NumberFormat("#,##0", "id_ID");

  @override
  void initState() {
    super.initState();
    loadProvinsi();
    _futureData = getData();
  }

  Future<void> loadProvinsi() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('tbs_harga').get();

    final provinsiSet = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['provinsi'] != null) {
        provinsiSet.add(data['provinsi']);
      }
    }

    setState(() {
      provinsiList = ["Semua", ...provinsiSet.toList()..sort()];
    });
  }

  Future<List<QueryDocumentSnapshot>> getData() async {
    Query query = FirebaseFirestore.instance.collection('tbs_harga');

    if (selectedProvinsi != "Semua") {
      query = query.where('provinsi', isEqualTo: selectedProvinsi);
    }

    query = query
        .where('tahun', isGreaterThanOrEqualTo: tahunAwal)
        .where('tahun', isLessThanOrEqualTo: tahunAkhir)
        .orderBy('tahun')
        .orderBy('bulan');

    final snapshot = await query.get();
    return snapshot.docs;
  }

  void refreshData() {
    setState(() {
      _futureData = getData();
    });
  }

  @override
  Widget build(BuildContext context) {
    const bulanList = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des'
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text("Grafik Harga TBS"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            /// FILTER
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProvinsi,
                    items: provinsiList
                        .map((prov) => DropdownMenuItem(
                              value: prov,
                              child: Text(prov),
                            ))
                        .toList(),
                    onChanged: (value) {
                      selectedProvinsi = value!;
                      refreshData();
                    },
                    decoration:
                        const InputDecoration(labelText: "Pilih Provinsi"),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: tahunAwal.toString(),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: "Tahun Awal"),
                          onChanged: (value) {
                            tahunAwal = int.tryParse(value) ?? 2026;
                          },
                          onFieldSubmitted: (_) => refreshData(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: tahunAkhir.toString(),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: "Tahun Akhir"),
                          onChanged: (value) {
                            tahunAkhir = int.tryParse(value) ?? 2026;
                          },
                          onFieldSubmitted: (_) => refreshData(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// GRAFIK
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 300, // tinggi grafik lebih kecil, bisa diubah sesuai kebutuhan
                child: FutureBuilder<List<QueryDocumentSnapshot>>(
                  future: _futureData,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("Data tidak tersedia"));
                    }

                    final docs = snapshot.data!;

                    Map<int, List<double>> bulanHarga = {};
                    List<double> semuaHarga = [];

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final int bulan = data['bulan'];
                      final double harga = (data['harga'] as num).toDouble();

                      bulanHarga.putIfAbsent(bulan, () => []);
                      bulanHarga[bulan]!.add(harga);
                    }

                    List<FlSpot> spots = [];

                    bulanHarga.forEach((bulan, hargaList) {
                      double nilai;
                      if (selectedProvinsi == "Semua") {
                        nilai = hargaList.reduce((a, b) => a + b) / hargaList.length;
                      } else {
                        nilai = hargaList.first;
                      }
                      semuaHarga.add(nilai);
                      spots.add(FlSpot((bulan - 1).toDouble(), nilai));
                    });

                    spots.sort((a, b) => a.x.compareTo(b.x));

                    double minHarga = semuaHarga.reduce((a, b) => a < b ? a : b);
                    double maxHarga = semuaHarga.reduce((a, b) => a > b ? a : b);

                    // Tambahkan margin ±20% supaya range lebih tinggi
                    double margin = (maxHarga - minHarga) * 0.2;
                    double adjustedMinY = (minHarga - margin).clamp(0, minHarga);
                    double adjustedMaxY = maxHarga + margin;

                    double range = adjustedMaxY - adjustedMinY;
                    double interval = (range / 10).ceilToDouble();
                    if (interval < 1) interval = 1;

                    return AspectRatio(
                      aspectRatio: 1.5,
                      child: LineChart(
                        LineChartData(
                          minY: adjustedMinY,
                          maxY: adjustedMaxY,
                          lineTouchData: LineTouchData(
                            handleBuiltInTouches: true,
                            touchTooltipData: LineTouchTooltipData(
                              tooltipBgColor: Colors.black87,
                              getTooltipItems: (touchedSpots) {
                                if (touchedSpots.isEmpty) return [];
                                final spot = touchedSpots.first;
                                return [
                                  LineTooltipItem(
                                    formatRupiah.format(spot.y.toInt()),
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            horizontalInterval: interval,
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: interval,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  if (value % interval != 0) return const SizedBox();
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
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() < bulanList.length) {
                                    return Text(bulanList[value.toInt()]);
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
                              isCurved: false,
                              barWidth: 3,
                              color: Colors.green,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}