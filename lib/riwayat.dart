import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'riwayat_detail.dart';
import 'riwayat2.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  String _selectedJenis = 'Semua Jenis';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPanen();
  }

  Future<void> _loadPanen() async {
    final data = await DBHelper.getAll();
    setState(() => _dataPanen = data);
  }

  // 🔹 Perbaikan utama _toDouble()
  double _toDouble(dynamic val) {
    if (val == null) return 0;
    if (val is double) return val;
    if (val is int) return val.toDouble();

    // Hapus semua karakter kecuali angka dan titik
    String s = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(s) ?? 0;
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

  List<Map<String, dynamic>> _getFilteredData() {
    List<Map<String, dynamic>> result = _dataPanen;

    if (_selectedJenis != 'Semua Jenis') {
      result = result.where((row) {
        final type =
            (row['type'] ?? '').toString().toLowerCase().trim();

        if (_selectedJenis == 'Panen') return type == 'panen';
        if (_selectedJenis == 'Pemupukan') return type == 'pemupukan';
        if (_selectedJenis == 'Pembabatan') return type == 'pembabatan';
        if (_selectedJenis == 'Penunasan') return type == 'penunasan';
        if (_selectedJenis == 'Penyemprotan') return type == 'penyemprotan';
        if (_selectedJenis == 'Kastrasi') return type == 'kastrasi';
        if (_selectedJenis == 'Sanitasi') return type == 'sanitasi';

        return true;
      }).toList();
    }

    if (_startDate != null && _endDate != null) {
      result = result.where((row) {
        final tgl = _parseTanggal(row['tanggal']);
        if (tgl == null) return false;
        return !tgl.isBefore(_startDate!) &&
            !tgl.isAfter(_endDate!);
      }).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    _applyTanggalFilter();
    final filteredData = _getFilteredData();

    return Scaffold(
      backgroundColor: const Color(0xFFFFE59A),
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Riwayat',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPanen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _filterCard(),
              const SizedBox(height: 24),
              const Text(
                "Daftar Riwayat",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (filteredData.isEmpty)
                _emptyState()
              else
                Column(
                  children: filteredData
                      .map((data) => _buildItem(data, "Local"))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> data, String sumber) {
    final type =
        (data['type'] ?? '').toString().toLowerCase().trim();

    final tgl = _parseTanggal(data['tanggal']);
    final tanggalStr =
        tgl != null ? DateFormat('d MMM yyyy').format(tgl) : '-';

    final berat = _toDouble(data['berat']);
    final harga = _toDouble(data['harga']);
    final biaya = _toDouble(data['biaya']);
    final lainnya = _toDouble(data['lainnya']);
    final jumlah = _toDouble(data['jumlah']);

    final totalBiaya = biaya + lainnya;

    String title;
    double nominal;

    switch (type) {
      case 'panen':
        final totalPanen = berat * harga;
        title = "Panen ${_formatter.format(berat)} Kg";
        nominal = totalPanen;
        break;

      case 'sanitasi':
        title = "Sanitasi";
        nominal = totalBiaya;
        break;

      case 'pemupukan':
        title = "Pemupukan ${data['jenisPupuk'] ?? ''}";
        nominal = totalBiaya; // sekarang muncul dengan benar
        break;

      case 'pembabatan':
        title = "Pembabatan ${_formatter.format(jumlah)} m²";
        nominal = totalBiaya;
        break;

      case 'penunasan':
        title = "Penunasan ${_formatter.format(jumlah)} Pohon";
        nominal = totalBiaya;
        break;

      case 'penyemprotan':
        title = "Penyemprotan ${data['jenisPupuk'] ?? ''}";
        nominal = totalBiaya;
        break;

      case 'kastrasi':
        title = "Kastrasi ${_formatter.format(jumlah)} Pohon";
        nominal = totalBiaya;
        break;

      default:
        title = type.isNotEmpty
            ? "${type[0].toUpperCase()}${type.substring(1)}"
            : "Perawatan";
        nominal = totalBiaya;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RiwayatDetailPage(data: data, sumber: sumber),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.agriculture,
                  color: Colors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tanggalStr,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54),
                  ),
                ],
              ),
            ),
            Text(
              "Rp ${_formatter.format(nominal)}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.inbox,
              size: 48, color: Colors.black38),
          SizedBox(height: 12),
          Text(
            "Belum ada data",
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _filterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            "Filter",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          const SizedBox(height: 12),
          _filterItem(
            icon: Icons.category,
            text: _selectedJenis,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const Riwayat2Page()),
              );
              if (result is String) {
                setState(() =>
                    _selectedJenis = result);
              }
            },
          ),
          const SizedBox(height: 12),
          _dropdownTanggal(),
        ],
      ),
    );
  }

  Widget _filterItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _dropdownTanggal() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTanggal,
          isExpanded: true,
          items: const [
            'Semua Tanggal',
            'Hari Ini',
            'Minggu Ini',
            'Bulan Ini',
            'Tahun Ini',
          ]
              .map((e) => DropdownMenuItem(
                  value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _selectedTanggal = v;
              _applyTanggalFilter();
            });
          },
        ),
      ),
    );
  }
}