import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_helper.dart';
import 'riwayat_detail.dart';
import 'riwayat2.dart';
import 'absensi_service.dart';
import 'absensi_models.dart';
import 'absensi_grafik_page.dart';
import 'user_session.dart';

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

  // ===== TAMBAHAN: RIWAYAT ABSENSI =====
  List<RiwayatAbsensi> _dataAbsensi = [];
  bool _loadingAbsensi = false;
  bool _sayaPemilikRoom = false;
  String? _errorAbsensi;

  // Disimpan supaya bisa dipakai membuka AbsensiGrafikPage (butuh roomId,
  // bukan cuma data riwayatnya saja).
  String? _roomIdSaya;

  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  String get _uid => UserSession.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadPanen();
    _loadAbsensi();
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

  // ===== TAMBAHAN: ambil riwayat absensi dari room saya (pemilik/pekerja) =====
  Future<void> _loadAbsensi() async {
    if (_uid.isEmpty) return;
    setState(() {
      _loadingAbsensi = true;
      _errorAbsensi = null;
    });

    try {
      final info = await AbsensiService.cariRoomSaya(_uid);
      if (info == null) {
        setState(() {
          _dataAbsensi = [];
          _roomIdSaya = null;
          _loadingAbsensi = false;
        });
        return;
      }

      _sayaPemilikRoom = info.sayaPemilik;
      _roomIdSaya = info.roomId;

      final hasil = await AbsensiService.getRiwayatRoom(
        roomId: info.roomId,
        userId: info.sayaPemilik ? null : _uid, // pemilik lihat semua, pekerja lihat punya sendiri
        start: _startDate,
        end: _endDate,
      );

      if (!mounted) return;
      setState(() {
        _dataAbsensi = hasil;
        _loadingAbsensi = false;
      });
    } catch (e) {
      // Penting: tanpa try/catch ini, kalau query Firestore gagal
      // (mis. index belum dibuat / FAILED_PRECONDITION), exception
      // tidak tertangani dan _loadingAbsensi tidak pernah di-reset,
      // sehingga UI terlihat "nyangkut" di kondisi loading terus.
      if (!mounted) return;
      setState(() {
        _loadingAbsensi = false;
        _errorAbsensi = "Gagal memuat riwayat absensi. Coba lagi nanti.";
      });
      debugPrint('RiwayatPage._loadAbsensi error: $e');
    }
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

    final bool tampilAbsensi = _selectedJenis == 'Absensi';
    final filteredData = tampilAbsensi ? <Map<String, dynamic>>[] : _getFilteredData();

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
        onRefresh: () async {
          await _loadPanen();
          await _loadAbsensi();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _filterCard(),
              const SizedBox(height: 24),
              Text(
                tampilAbsensi ? "Riwayat Absensi" : "Daftar Riwayat",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (tampilAbsensi)
                _bagianAbsensi()
              else if (filteredData.isEmpty)
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

  // ===== TAMBAHAN: bagian tampilan riwayat absensi =====
  Widget _bagianAbsensi() {
    if (_loadingAbsensi) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorAbsensi != null) {
      return Center(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  _errorAbsensi!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadAbsensi,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Coba Lagi"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_dataAbsensi.isEmpty) {
      return _emptyState();
    }

    return Column(
      children: _dataAbsensi.map(_buildItemAbsensi).toList(),
    );
  }

  Widget _buildItemAbsensi(RiwayatAbsensi r) {
    final (warna, ikon, label) = infoStatusAbsensi(r.status);
    final punyaJam = r.status == StatusAbsensi.hadir || r.status == StatusAbsensi.telat;
    // True kalau hari itu sudah checkout DAN ada ringkasan aktivitas
    // (menit di dalam/luar area) yang bisa ditampilkan.
    final punyaAktivitas = r.jamCheckout != null && r.ringkasan != null;

    DateTime? tgl;
    try {
      tgl = DateFormat('yyyy-MM-dd').parse(r.tanggal);
    } catch (_) {}
    final tanggalStr = tgl != null ? DateFormat('d MMM yyyy').format(tgl) : r.tanggal;

    return GestureDetector(
      onTap: () => _bukaDetailAbsensi(r),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: warna.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(ikon, color: warna),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Pemilik lihat nama pekerjanya, pekerja cukup lihat statusnya
                        _sayaPemilikRoom ? r.nama : label,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        punyaJam
                            ? "$tanggalStr · ${r.jam.substring(0, 5)}"
                            : tanggalStr,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: warna.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: warna, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            // Ringkasan aktivitas singkat langsung di kartu list, supaya
            // pekerja/pemilik bisa lihat sekilas tanpa perlu buka detail.
            if (punyaAktivitas) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _miniStat(Icons.check_circle_outline, Colors.green,
                        "${r.ringkasan!.totalMenitDiDalam}m", "dalam"),
                    const SizedBox(width: 14),
                    _miniStat(Icons.error_outline, Colors.redAccent,
                        "${r.ringkasan!.totalMenitDiLuar}m", "luar"),
                    const SizedBox(width: 14),
                    _miniStat(Icons.logout, Colors.orange.shade700,
                        "${r.ringkasan!.jumlahKeluarArea}x", "keluar"),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData ikon, Color warna, String nilai, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 13, color: warna),
        const SizedBox(width: 4),
        Text(
          "$nilai $label",
          style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _bukaDetailAbsensi(RiwayatAbsensi r) {
    DateTime? tgl;
    try {
      tgl = DateFormat('yyyy-MM-dd').parse(r.tanggal);
    } catch (_) {}
    final tanggalStr = tgl != null ? DateFormat('d MMM yyyy').format(tgl) : r.tanggal;
    final punyaAktivitas = r.jamCheckout != null && r.ringkasan != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(tanggalStr, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 16),
                if (r.fotoBase64 != null && r.fotoBase64!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(r.fotoBase64!),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 12),
                if (r.status == StatusAbsensi.izin || r.status == StatusAbsensi.sakit)
                  Text(
                    "${r.status == StatusAbsensi.sakit ? 'Alasan sakit' : 'Alasan izin'}: ${r.keterangan ?? '-'}",
                  )
                else
                  Text(
                    "Jam absen: ${r.jam.substring(0, 5)} "
                    "(${r.status == StatusAbsensi.telat ? 'Telat' : 'Hadir'})",
                  ),
                if (r.lat != null && r.lng != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final url = Uri.parse('https://www.google.com/maps?q=${r.lat},${r.lng}');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.location_on, color: Colors.green),
                      label: const Text("Lihat Lokasi Absen", style: TextStyle(color: Colors.green)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                    ),
                  ),
                ],

                // ===== TAMBAHAN: ringkasan + tombol lihat grafik aktivitas =====
                if (punyaAktivitas) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.insights, size: 16, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      const Text(
                        "Aktivitas Hari Itu",
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        "Checkout ${r.jamCheckout!.substring(0, 5)}"
                        "${r.checkoutOtomatis ? ' (otomatis)' : ''}",
                        style: const TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _kartuRingkasanMini(
                          ikon: Icons.check_circle_outline,
                          warna: const Color(0xFF2E7D32),
                          nilai: "${r.ringkasan!.totalMenitDiDalam}",
                          satuan: "mnt",
                          label: "Di Dalam",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kartuRingkasanMini(
                          ikon: Icons.error_outline,
                          warna: const Color(0xFFE53935),
                          nilai: "${r.ringkasan!.totalMenitDiLuar}",
                          satuan: "mnt",
                          label: "Di Luar",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _kartuRingkasanMini(
                          ikon: Icons.logout,
                          warna: Colors.orange.shade700,
                          nilai: "${r.ringkasan!.jumlahKeluarArea}",
                          satuan: "x",
                          label: "Keluar",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (_roomIdSaya == null)
                          ? null
                          : () {
                              Navigator.pop(ctx); // tutup bottom sheet dulu
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AbsensiGrafikPage(
                                    roomId: _roomIdSaya!,
                                    userId: r.userId,
                                    nama: r.nama,
                                    tanggal: r.tanggal,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      label: const Text(
                        "Lihat Grafik Aktivitas Lengkap",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kartuRingkasanMini({
    required IconData ikon,
    required Color warna,
    required String nilai,
    required String satuan,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(ikon, size: 16, color: warna),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: nilai,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: warna, height: 1),
                ),
                TextSpan(
                  text: " $satuan",
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
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
                setState(() => _selectedJenis = result);
                if (result == 'Absensi') {
                  // Tunda sampai animasi transisi pop selesai render,
                  // supaya tidak numpuk sama query Firestore + rebuild
                  // berat (penyebab "acquireNextBufferLocked: Already
                  // acquired max frames").
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _loadAbsensi();
                  });
                }
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadAbsensi();
            });
          },
        ),
      ),
    );
  }
}