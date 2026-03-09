import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'tambahpanen.dart';
import 'database_helper.dart';
import 'data_catat_panen.dart';

class CatatPanenPage extends StatefulWidget {
  const CatatPanenPage({super.key});

  @override
  State<CatatPanenPage> createState() => _CatatPanenPageState();
}

class _CatatPanenPageState extends State<CatatPanenPage> {
  String _selectedTanggal = 'Semua Tanggal';
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _dataPanen = [];
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  void initState() {
    super.initState();
    _loadPanen();
  }

  Future<void> _loadPanen() async {
    final allData = await DBHelper.getAll();
    setState(() {
      _dataPanen = allData
          .where((row) =>
              (row['type'] ?? '').toString().toLowerCase() == 'panen')
          .toList();
    });
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

  List<Map<String, dynamic>> _getFilteredData() {
    List<Map<String, dynamic>> result = _dataPanen;

    if (_startDate != null && _endDate != null) {
      result = result.where((row) {
        final tgl = _parseTanggal(row['tanggal']);
        if (tgl == null) return false;
        return !tgl.isBefore(_startDate!) && !tgl.isAfter(_endDate!);
      }).toList();
    }

    return result;
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    _applyTanggalFilter();
    final filteredData = _getFilteredData();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3D5),
              Color(0xFFFFC34A),
            ],
          ),
        ),
        child: Column(
          children: [
            // =================== APPBAR ===================
            PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                height: 56,
                color: const Color(0xFF00994D),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Catat Panen",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    )
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= BOX ATAS =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Pantau Performa Kebun",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Mulai catat panen untuk optimalkan hasil kebun Anda.",
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DataCatatPanenPage(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFF00994D)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "Cek Laporan Kebun",
                                style: TextStyle(color: Color(0xFF00994D)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ================== JUDUL + FILTER SEJARAH ===================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Priode Panen",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedTanggal,
                              items: const [
                                'Semua Tanggal',
                                'Hari Ini',
                                'Minggu Ini',
                                'Bulan Ini',
                                'Tahun Ini'
                              ]
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _selectedTanggal = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ================== CARD DATA ===================
                    ...filteredData.map((data) {
                      final tgl = _parseTanggal(data['tanggal']);
                      final tanggalStr =
                          tgl != null ? DateFormat('d MMM yyyy').format(tgl) : '-';
                      final berat = _toDouble(data['berat']);
                      final harga = _toDouble(data['harga']);
                      final total = berat * harga;

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Panen",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  tanggalStr,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Total Berat", style: const TextStyle(fontSize: 13)),
                                Text("${_formatter.format(berat)} Kg",
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black54)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Harga TBS/KG", style: const TextStyle(fontSize: 13)),
                                Text("Rp ${_formatter.format(harga)}",
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black54)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Total Harga", style: const TextStyle(fontSize: 13)),
                                Text("Rp ${_formatter.format(total)}",
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black54)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ),

            // ================= BUTTON BAWAH =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TambahPanenPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006622),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Catat Panen Baru",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}