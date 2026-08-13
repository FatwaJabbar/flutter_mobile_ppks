// file: absensi_grafik_page.dart
// Halaman grafik aktivitas harian pekerja (di dalam vs di luar area kerja).
// Dibuka SETELAH checkout (pekerja) ATAU saat pemilik menekan ikon grafik
// pada kartu anggota. Halaman PENUH (push), bukan popup/dialog.
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'absensi_service.dart';
import 'absensi_aktivitas_models.dart';

class AbsensiGrafikPage extends StatefulWidget {
  final String roomId;
  final String userId;
  final String nama;
  final String? tanggal; // null = hari ini

  const AbsensiGrafikPage({
    super.key,
    required this.roomId,
    required this.userId,
    required this.nama,
    this.tanggal,
  });

  @override
  State<AbsensiGrafikPage> createState() => _AbsensiGrafikPageState();
}

class _AbsensiGrafikPageState extends State<AbsensiGrafikPage> {
  // ================= DEBUG / TESTING ONLY =================
  // Dikembalikan ke `false` untuk perilaku produksi normal: grafik
  // menampilkan data checkpoint lokasi ASLI dari Firestore. Set sementara
  // ke `true` kalau butuh preview tampilan tanpa data asli -- TAPI WAJIB
  // dikembalikan ke `false` lagi sebelum build rilis, karena kalau lupa,
  // grafik yang tampil bukan data asli pekerja, melainkan data dummy ini
  // terus-menerus.
  static const bool _debugPakaiDataDummy = false;

  static const _cGreen = Color(0xFF2E7D32);
  static const _cRed = Color(0xFFE53935);
  static const _cBg = Color(0xFFF4F6F8);
  static const _cTextPrimary = Color(0xFF212121);
  static const _cTextSecondary = Color(0xFF757575);

  bool _loading = true;
  List<LokasiCheckpoint> _checkpoints = [];
  RingkasanAktivitas _ringkasan = RingkasanAktivitas.kosong();

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    if (_debugPakaiDataDummy) {
      final dummy = _buatDataDummyPenuh();
      if (!mounted) return;
      setState(() {
        _checkpoints = dummy;
        _ringkasan = AbsensiService.hitungRingkasan(dummy);
        _loading = false;
      });
      return;
    }

    final checkpoints = await AbsensiService.getLokasiLogHariIni(
      roomId: widget.roomId,
      userId: widget.userId,
      tanggal: widget.tanggal,
    );
    if (!mounted) return;
    setState(() {
      _checkpoints = checkpoints;
      _ringkasan = AbsensiService.hitungRingkasan(checkpoints);
      _loading = false;
    });
  }

  /// Data dummy: checkpoint tiap 30 menit dari 07:30 sampai 17:00 (seolah
  /// hari kerja penuh sampai batas checkout), dengan 8 dari 20 checkpoint
  /// (= 40%) berstatus "di luar area", dikelompokkan jadi 2 periode (siang
  /// & sore) supaya polanya realistis -- bukan acak titik demi titik.
  /// Hanya dipakai kalau [_debugPakaiDataDummy] di-set true untuk testing.
  List<LokasiCheckpoint> _buatDataDummyPenuh() {
    final tanggal = DateTime.now();
    final mulai = DateTime(tanggal.year, tanggal.month, tanggal.day, 7, 30);
    const totalTitik = 20; // 07:30 -> 17:00, interval 30 menit

    // Index checkpoint yang ditandai "di luar area" (2 periode, total 8/20 = 40%)
    const luarIndex = {5, 6, 7, 8, 13, 14, 15, 16};

    return List.generate(totalTitik, (i) {
      final waktu = mulai.add(Duration(minutes: 30 * i));
      return LokasiCheckpoint(
        waktu: waktu,
        diDalamArea: !luarIndex.contains(i),
        lat: 0,
        lng: 0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        backgroundColor: _cGreen,
        elevation: 0,
        title: Text("Aktivitas - ${widget.nama}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _checkpoints.isEmpty
              ? const Center(child: Text("Belum ada data lokasi untuk hari ini."))
              : RefreshIndicator(
                  onRefresh: _muat,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_debugPakaiDataDummy) _bannerDebug(),
                        if (_debugPakaiDataDummy) const SizedBox(height: 12),
                        _kartuRingkasan(),
                        const SizedBox(height: 20),
                        _kartu(
                          judul: "Proporsi Waktu",
                          child: _pieChart(),
                        ),
                        const SizedBox(height: 16),
                        _kartu(
                          judul: "Linimasa Lokasi",
                          subjudul: "Setiap titik = 1 pengecekan lokasi (tiap 30 menit)",
                          child: _timelineChart(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _bannerDebug() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade700, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Mode preview: data di bawah ini DUMMY, bukan data asli.",
              style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Wrapper kartu putih konsisten (shadow tipis, rounded, judul + subjudul).
  Widget _kartu({required String judul, String? subjudul, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _cTextPrimary)),
          if (subjudul != null) ...[
            const SizedBox(height: 3),
            Text(subjudul, style: const TextStyle(fontSize: 11.5, color: _cTextSecondary)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _kartuRingkasan() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            ikon: Icons.check_circle_outline,
            warna: _cGreen,
            nilai: "${_ringkasan.totalMenitDiDalam}",
            satuan: "mnt",
            label: "Di Dalam",
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            ikon: Icons.error_outline,
            warna: _cRed,
            nilai: "${_ringkasan.totalMenitDiLuar}",
            satuan: "mnt",
            label: "Di Luar",
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            ikon: Icons.logout,
            warna: Colors.orange.shade700,
            nilai: "${_ringkasan.jumlahKeluarArea}",
            satuan: "x",
            label: "Keluar Area",
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData ikon,
    required Color warna,
    required String nilai,
    required String satuan,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: warna.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(ikon, size: 18, color: warna),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: nilai,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold, color: _cTextPrimary, height: 1),
                ),
                TextSpan(
                  text: " $satuan",
                  style: const TextStyle(fontSize: 11, color: _cTextSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: _cTextSecondary)),
        ],
      ),
    );
  }

  Widget _pieChart() {
    final totalJamText = () {
      final totalMnt = _ringkasan.totalMenit.toInt();
      final j = totalMnt ~/ 60;
      final m = totalMnt % 60;
      if (j == 0) return "${m}m";
      if (m == 0) return "${j}j";
      return "${j}j ${m}m";
    }();

    return SizedBox(
      height: 190,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 48,
                    sections: [
                      PieChartSectionData(
                        value: _ringkasan.totalMenitDiDalam.toDouble().clamp(0.0001, double.infinity),
                        color: _cGreen,
                        title: _ringkasan.totalMenitDiDalam > 0
                            ? '${_ringkasan.persenDiDalam.toStringAsFixed(0)}%'
                            : '',
                        radius: 46,
                        titleStyle: const TextStyle(
                            fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      PieChartSectionData(
                        value: _ringkasan.totalMenitDiLuar.toDouble().clamp(0.0001, double.infinity),
                        color: _cRed,
                        title: _ringkasan.totalMenitDiLuar > 0
                            ? '${_ringkasan.persenDiLuar.toStringAsFixed(0)}%'
                            : '',
                        radius: 46,
                        titleStyle: const TextStyle(
                            fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(totalJamText,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: _cTextPrimary)),
                    const Text("total tercatat",
                        style: TextStyle(fontSize: 9.5, color: _cTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legenda(_cGreen, "Di dalam area", _ringkasan.persenDiDalam),
              const SizedBox(height: 14),
              _legenda(_cRed, "Di luar area", _ringkasan.persenDiLuar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legenda(Color warna, String label, double persen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: _cTextPrimary, fontWeight: FontWeight.w500)),
            Text("${persen.toStringAsFixed(0)}%",
                style: const TextStyle(fontSize: 11, color: _cTextSecondary)),
          ],
        ),
      ],
    );
  }

  String _formatJam(DateTime d) =>
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  /// Grafik garis step: 1 = di dalam area, 0 = di luar area. Area di bawah
  /// garis diberi fill tipis warna hijau, gridline halus, dan tooltip saat
  /// disentuh -- satu warna garis konsisten (bukan titik warna-warni per
  /// step) supaya kesannya rapi/profesional.
  Widget _timelineChart() {
    final spots = List.generate(
      _checkpoints.length,
      (i) => FlSpot(i.toDouble(), _checkpoints[i].diDalamArea ? 1 : 0),
    );

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: -0.15,
          maxY: 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              left: BorderSide(color: Colors.grey.shade300, width: 1),
              right: BorderSide.none,
              top: BorderSide.none,
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.x.toInt();
                if (i < 0 || i >= _checkpoints.length) return null;
                final cp = _checkpoints[i];
                return LineTooltipItem(
                  "${_formatJam(cp.waktu)}\n${cp.diDalamArea ? 'Di dalam area' : 'Di luar area'}",
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: 1,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value == 1 ? "Dalam" : (value == 0 ? "Luar" : ""),
                    style: const TextStyle(fontSize: 10.5, color: _cTextSecondary),
                  ),
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (_checkpoints.length / 6).clamp(1, _checkpoints.length).toDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= _checkpoints.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _formatJam(_checkpoints[i].waktu),
                      style: const TextStyle(fontSize: 9.5, color: _cTextSecondary),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              isStepLineChart: true,
              lineChartStepData: const LineChartStepData(stepDirection: 0),
              color: _cGreen,
              barWidth: 2.2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Color(0x142E7D32)),
            ),
          ],
        ),
      ),
    );
  }
}