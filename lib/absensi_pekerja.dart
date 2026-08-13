// file: absensi_pekerja.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'absensi_service.dart';
import 'absensi_models.dart';
import 'absensi_face_camera.dart';
import 'geofence_kebun.dart';
import 'user_session.dart';
import 'absensi_lokasi_tracker.dart';
import 'absensi_grafik_page.dart';
import 'absensi_background_service.dart';

class AbsensiPekerjaPage extends StatefulWidget {
  /// Diisi otomatis kalau halaman ini dibuka lewat link undangan
  /// (ppks://gabung?kode=...). Kalau ada, kode langsung diisi & dicoba
  /// bergabung otomatis.
  final String? kodeAwal;

  const AbsensiPekerjaPage({super.key, this.kodeAwal});

  @override
  State<AbsensiPekerjaPage> createState() => _AbsensiPekerjaPageState();
}

class _AbsensiPekerjaPageState extends State<AbsensiPekerjaPage> {
  String? _roomId;
  bool _loading = true;
  bool _bergabung = false;
  final _kodeC = TextEditingController();
  RiwayatAbsensi? _statusHariIni;

  // ===== Tracking lokasi berkala + countdown "di luar area" + checkout =====
  AbsensiLokasiTracker? _tracker;
  bool _sedangCheckout = false;

  // Dijadwalkan pas batas jam 17:00 (enable tombol Checkout) & 17:10
  // (checkout otomatis) supaya UI update sendiri tanpa perlu reload manual.
  Timer? _timerJadwalCheckout;

  // Cache foto yang sudah di-decode, supaya base64Decode tidak jalan
  // ulang tiap rebuild (penyebab foto terlihat kedip-kedip sebelumnya).
  Uint8List? _fotoBytesCache;
  String? _fotoBytesCacheKey;

  String get _uid => UserSession.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _nama =>
      UserSession.nama ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Pekerja';

  @override
  void initState() {
    super.initState();
    _muatStatus();
  }

  @override
  void dispose() {
    _tracker?.dispose();
    _timerJadwalCheckout?.cancel();
    super.dispose();
  }

  Future<void> _muatStatus() async {
    final roomId = await AbsensiService.getMyRoomId(_uid);
    if (roomId != null && roomId.isNotEmpty) {
      _roomId = roomId;
      try {
        await _muatDetailRoom();
      } catch (e) {
        debugPrint('Gagal memuat detail room: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memuat data absensi. Coba lagi.')),
          );
        }
      }
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted) setState(() => _loading = false);

    // Kalau dibuka lewat link undangan dan belum tergabung ke room manapun,
    // langsung isi kode & coba gabung otomatis.
    if (widget.kodeAwal != null && widget.kodeAwal!.isNotEmpty) {
      _kodeC.text = widget.kodeAwal!;
      await _gabungRoom();
    }
  }

  /// Memuat status absen hari ini. Kalau BELUM ada record sama sekali dan
  /// waktu sekarang SUDAH lewat jam 12:00, pekerja otomatis dicatat Alpha
  /// di sini. Kalau SUDAH Hadir/Telat tapi belum Checkout dan sudah lewat
  /// jam 17:10, pekerja otomatis di-Checkout oleh sistem (tanpa
  /// keterangan) supaya grafik aktivitas hari itu tetap terbentuk.
  Future<void> _muatDetailRoom() async {
    if (_roomId == null) return;

    var status = await AbsensiService.getStatusHariIni(roomId: _roomId!, userId: _uid);

    if (status == null && AbsensiService.sudahLewatBatasAlpha()) {
      try {
        await AbsensiService.catatAlphaOtomatis(roomId: _roomId!, userId: _uid, nama: _nama);
        status = await AbsensiService.getStatusHariIni(roomId: _roomId!, userId: _uid);
      } catch (e) {
        debugPrint('Gagal catat alpha otomatis: $e');
      }
    }

    if (status != null &&
        AbsensiService.bisaCheckout(status) &&
        AbsensiService.sudahLewatBatasCheckoutOtomatis()) {
      try {
        _tracker?.berhenti();
        await AbsensiBackgroundService.berhenti();
        await AbsensiService.catatCheckout(roomId: _roomId!, userId: _uid, otomatis: true);
        status = await AbsensiService.getStatusHariIni(roomId: _roomId!, userId: _uid);
      } catch (e) {
        debugPrint('Gagal checkout otomatis: $e');
      }
    }

    if (!mounted) return;
    _perbaruiFotoCache(status);
    setState(() => _statusHariIni = status);

    _mungkinMulaiTracker();
    _jadwalkanTimerCheckout();
  }

  /// Decode foto sekali saja per record (dikunci pakai id dokumen riwayat),
  /// bukan tiap kali widget rebuild.
  void _perbaruiFotoCache(RiwayatAbsensi? status) {
    if (status?.fotoBase64 == null || status!.fotoBase64!.isEmpty) {
      _fotoBytesCache = null;
      _fotoBytesCacheKey = null;
      return;
    }
    if (_fotoBytesCacheKey == status.id) return; // sudah ke-cache
    _fotoBytesCache = base64Decode(status.fotoBase64!);
    _fotoBytesCacheKey = status.id;
  }

  /// Mulai pelacakan lokasi berkala (tiap 30 menit) kalau pekerja sudah
  /// absen Hadir/Telat hari ini dan belum Checkout. Dihentikan otomatis
  /// begitu status berubah (mis. sudah Checkout).
  ///
  /// Ada DUA lapis tracker: [_tracker] (foreground, cuma jalan selagi
  /// halaman ini terbuka -- untuk countdown badge real-time) dan
  /// [AbsensiBackgroundService] (foreground SERVICE Android -- tetap
  /// jalan walau app ditutup/di-swipe/cache dihapus, sampai Checkout).
  void _mungkinMulaiTracker() {
    if (_roomId != null && AbsensiService.bisaCheckout(_statusHariIni)) {
      _tracker ??= AbsensiLokasiTracker(roomId: _roomId!, userId: _uid);
      _tracker!.mulai();

      AbsensiBackgroundService.mintaSemuaIzin().then((diizinkan) {
        if (diizinkan && _roomId != null) {
          AbsensiBackgroundService.mulai(roomId: _roomId!, userId: _uid);
        }
      });
    } else {
      _tracker?.berhenti();
      AbsensiBackgroundService.berhenti();
    }
  }

  /// Menjadwalkan satu Timer ke batas waktu terdekat yang relevan buat
  /// tombol Checkout: jam 17:00 (supaya tombolnya auto-enable) atau jam
  /// 17:10 (supaya checkout otomatis jalan) -- tanpa pekerja perlu reload
  /// halaman secara manual. Timer di-reschedule sendiri tiap kali batas
  /// tercapai, sampai tidak ada lagi batas yang perlu ditunggu.
  void _jadwalkanTimerCheckout() {
    _timerJadwalCheckout?.cancel();
    _timerJadwalCheckout = null;

    if (!AbsensiService.bisaCheckout(_statusHariIni)) return;

    final now = DateTime.now();
    final batasCheckout = DateTime(
      now.year,
      now.month,
      now.day,
      AbsensiService.jamBatasCheckout,
      AbsensiService.menitBatasCheckout,
    );
    final batasOtomatis = DateTime(
      now.year,
      now.month,
      now.day,
      AbsensiService.jamBatasCheckoutOtomatis,
      AbsensiService.menitBatasCheckoutOtomatis,
    );

    DateTime? target;
    if (now.isBefore(batasCheckout)) {
      target = batasCheckout;
    } else if (now.isBefore(batasOtomatis)) {
      target = batasOtomatis;
    }
    if (target == null) return; // sudah lewat semua batas, tidak perlu timer

    _timerJadwalCheckout = Timer(target.difference(now) + const Duration(seconds: 1), () async {
      if (!mounted) return;

      if (AbsensiService.sudahLewatBatasCheckoutOtomatis() &&
          AbsensiService.bisaCheckout(_statusHariIni)) {
        // Batas 17:10 tercapai selagi halaman terbuka -> checkout otomatis,
        // sama seperti yang dilakukan _muatDetailRoom saat pertama dibuka.
        _tracker?.berhenti();
        await AbsensiBackgroundService.berhenti();
        await AbsensiService.catatCheckout(roomId: _roomId!, userId: _uid, otomatis: true);
        await _muatDetailRoom();
      } else {
        // Batas 17:00 tercapai -> cukup rebuild supaya tombol Checkout
        // yang tadinya disabled jadi enabled, lalu jadwalkan batas
        // berikutnya (17:10).
        setState(() {});
        _jadwalkanTimerCheckout();
      }
    });
  }

  Future<void> _gabungRoom() async {
    if (_kodeC.text.trim().isEmpty) return;
    setState(() => _bergabung = true);

    final room = await AbsensiService.getRoomByKode(_kodeC.text);
    if (room == null) {
      setState(() => _bergabung = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kode akses tidak ditemukan")),
      );
      return;
    }

    await AbsensiService.joinRoom(roomId: room.roomId, userId: _uid, nama: _nama);
    setState(() {
      _roomId = room.roomId;
      _bergabung = false;
    });
    await _muatDetailRoom();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Berhasil bergabung ke ${room.namaKebun}")),
    );
  }

  // ================= CHECKOUT =================
  /// Checkout MANUAL (ditekan pekerja). Hanya aktif mulai jam 17:00 --
  /// tombolnya sendiri sudah disembunyikan/nonaktif sebelum itu, ini
  /// pengaman tambahan di level logika.
  Future<void> _checkout() async {
    if (_roomId == null || _sedangCheckout) return;
    if (!AbsensiService.sudahBolehCheckout()) return;

    setState(() => _sedangCheckout = true);

    _timerJadwalCheckout?.cancel();
    _tracker?.berhenti();
    await AbsensiBackgroundService.berhenti();
    await AbsensiService.catatCheckout(roomId: _roomId!, userId: _uid, otomatis: false);

    if (!mounted) return;
    setState(() => _sedangCheckout = false);
    await _muatDetailRoom();
    if (!mounted) return;

    // Pindah halaman penuh ke grafik aktivitas (bukan popup/dialog).
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbsensiGrafikPage(roomId: _roomId!, userId: _uid, nama: _nama),
      ),
    );
  }

  // ================= ALUR ABSEN (Hadir / Izin / Sakit) =================
  Future<void> _mulaiProsesAbsensi(StatusAbsensi jenis) async {
    if (AbsensiService.sudahLewatBatasAlpha()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Sudah melewati batas waktu absensi (12:00). Anda otomatis tercatat Alpha.",
          ),
          duration: Duration(seconds: 4),
        ),
      );
      await _muatDetailRoom();
      return;
    }

    String? keterangan;
    if (jenis != StatusAbsensi.hadir) {
      keterangan = await _mintaKeterangan(jenis);
      if (keterangan == null) return; // dibatalkan
    }

    final posisi = await _ambilLokasi(jenis);
    if (posisi == null) return;
    if (!mounted) return;

    final posisiTerkonfirmasi = await Navigator.push<Position>(
      context,
      MaterialPageRoute(builder: (_) => _LokasiKonfirmasiPage(posisiAwal: posisi, jenis: jenis)),
    );
    if (posisiTerkonfirmasi == null || !mounted) return;

    final foto = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AbsensiFaceCameraPage()),
    );
    if (foto == null || !mounted) return;

    await _prosesDanSimpanAbsen(
      foto: foto,
      posisi: posisiTerkonfirmasi,
      jenis: jenis,
      keterangan: keterangan,
    );
  }

  Future<String?> _mintaKeterangan(StatusAbsensi jenis) async {
    final label = jenis == StatusAbsensi.sakit ? "Sakit" : "Izin";
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8E1),
        title: Text("Ajukan $label"),
        content: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: "Alasan/keterangan $label",
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Lanjut"),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return c.text.trim().isEmpty ? label : c.text.trim();
  }

  Future<void> _prosesDanSimpanAbsen({
    required dynamic foto,
    required Position posisi,
    required StatusAbsensi jenis,
    String? keterangan,
  }) async {
    final fotoBase64 = base64Encode(foto);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProsesAbsenDialog(
        proses: () => AbsensiService.catatAbsensi(
          roomId: _roomId!,
          userId: _uid,
          nama: _nama,
          fotoBase64: fotoBase64,
          lat: posisi.latitude,
          lng: posisi.longitude,
          jenis: jenis,
          keterangan: keterangan,
        ),
      ),
    );

    await _muatDetailRoom();
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AbsenSuksesPage(
          posisi: posisi,
          status: _statusHariIni,
          onSelesai: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<Position?> _ambilLokasi(StatusAbsensi jenis) async {
    if (!mounted) return null;

    final layananAktif = await Geolocator.isLocationServiceEnabled();
    if (!layananAktif) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aktifkan GPS/Lokasi HP kamu dulu untuk bisa absen")),
      );
      return null;
    }

    LocationPermission izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }

    if (izin == LocationPermission.denied) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Izin lokasi ditolak. Absen butuh akses lokasi.")),
      );
      return null;
    }

    if (izin == LocationPermission.deniedForever) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Izin lokasi diblokir permanen. Aktifkan lewat Pengaturan > Aplikasi > Izin Lokasi."),
        ),
      );
      return null;
    }

    Position posisi;
    try {
      posisi = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengambil lokasi, coba lagi")),
      );
      return null;
    }

    if (jenis == StatusAbsensi.hadir &&
        !GeofenceKebun.isInside(posisi.latitude, posisi.longitude)) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Anda berada di luar area kerja. Absen Hadir hanya bisa dilakukan di dalam area kerja."),
          duration: Duration(seconds: 4),
        ),
      );
      return null;
    }

    return posisi;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Absensi - Pekerja", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_roomId == null ? _formGabung() : _panelAbsen()),
    );
  }

  Widget _formGabung() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.badge_outlined, size: 80, color: Colors.green),
          const SizedBox(height: 10),
          const Text(
            "Masukkan Kode Akses yang diberikan oleh pemilik ",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _kodeC,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: "Kode Akses (contoh: KBN-7X3K9)",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: _bergabung ? null : _gabungRoom,
              child: _bergabung
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("Gabung Room Absensi"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelAbsen() {
    if (_statusHariIni != null) {
      return _kartuSudahAbsen(_statusHariIni!);
    }
    return _kartuBelumAbsen();
  }

  Widget _kartuBelumAbsen() {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_time_filled, size: 56, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Anda belum absen hari ini",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Batas absen tepat waktu pukul 07:40.\n"
                  "Batas terakhir absen/izin/sakit pukul 12:00 -- lewat dari itu otomatis tercatat Alpha.\n"
                  "Hadir: wajib di dalam area kerja. Izin/Sakit: boleh dari mana saja.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _mulaiProsesAbsensi(StatusAbsensi.hadir),
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text("Absen Hadir", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      side: const BorderSide(color: Colors.blueGrey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _mulaiProsesAbsensi(StatusAbsensi.izin),
                    icon: const Icon(Icons.event_busy, color: Colors.blueGrey),
                    label: const Text("Izin", style: TextStyle(color: Colors.blueGrey)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _mulaiProsesAbsensi(StatusAbsensi.sakit),
                    icon: const Icon(Icons.local_hospital, color: Colors.redAccent),
                    label: const Text("Sakit", style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kartuSudahAbsen(RiwayatAbsensi r) {
    final (warna, ikon, label) = infoStatusAbsensi(r.status);
    final punyaJam = r.status == StatusAbsensi.hadir || r.status == StatusAbsensi.telat;
    final bisaCheckout = AbsensiService.bisaCheckout(r);
    final bolehCheckoutSekarang = AbsensiService.sudahBolehCheckout();

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: warna.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(ikon, size: 56, color: warna),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Kamu sudah tercatat hari ini",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: warna.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    punyaJam ? "$label \u00b7 ${r.jam.substring(0, 5)}" : label,
                    style: TextStyle(color: warna, fontWeight: FontWeight.w700),
                  ),
                ),
                if (r.keterangan != null && r.keterangan!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(r.keterangan!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                ],
                if (_fotoBytesCache != null) ...[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    // Pakai bytes yang sudah di-cache (bukan decode ulang
                    // tiap build) supaya gambar tidak kedip-kedip.
                    child: Image.memory(
                      _fotoBytesCache!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ],

                // ===== Bagian Checkout / Grafik Aktivitas =====
                if (bisaCheckout) ...[
                  const SizedBox(height: 20),
                  // Countdown "di luar area" diisolasi ke widget kecil
                  // sendiri yang listen langsung ke tracker -- supaya
                  // update tiap detik TIDAK ikut rebuild kartu ini
                  // (termasuk foto di atas).
                  if (_tracker != null) _CountdownLuarAreaBadge(tracker: _tracker!),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bolehCheckoutSekarang ? Colors.green : Colors.grey,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      // Tombol selalu tampil; disabled sebelum jam 17:00
                      // dan otomatis enable sendiri saat jamnya tiba
                      // (lihat _jadwalkanTimerCheckout), tanpa reload.
                      onPressed: (!bolehCheckoutSekarang || _sedangCheckout) ? null : _checkout,
                      icon: _sedangCheckout
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.logout, color: Colors.white),
                      label: Text(
                        bolehCheckoutSekarang ? "Checkout" : "Checkout (aktif mulai 17:00)",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else if (r.jamCheckout != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AbsensiGrafikPage(roomId: _roomId!, userId: _uid, nama: _nama),
                        ),
                      ),
                      icon: const Icon(Icons.insights, color: Colors.green),
                      label: const Text("Lihat Grafik Aktivitas Hari Ini",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Text(
                  "Lihat riwayat lengkap absensimu di tab Riwayat pada menu bawah.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.black38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge kecil "Di luar area sejak: HH:MM:SS". Widget terpisah supaya
/// hanya bagian ini yang rebuild tiap detik lewat ValueListenableBuilder,
/// tidak menyeret seluruh kartu status (dan foto di dalamnya) ikut
/// rebuild -- ini yang sebelumnya menyebabkan foto kedip-kedip.
class _CountdownLuarAreaBadge extends StatelessWidget {
  final AbsensiLokasiTracker tracker;
  const _CountdownLuarAreaBadge({required this.tracker});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration?>(
      valueListenable: tracker.countdownDiLuarArea,
      builder: (context, durasi, _) {
        if (durasi == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "Di luar area sejak: ${_formatDurasi(durasi)}",
            style: const TextStyle(
                fontSize: 11.5, color: Colors.redAccent, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

String _formatDurasi(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return "$h:$m:$s";
}

/* ============================================================
   HALAMAN: KONFIRMASI LOKASI DENGAN PETA
   ============================================================ */
class _LokasiKonfirmasiPage extends StatefulWidget {
  final Position posisiAwal;
  final StatusAbsensi jenis;
  const _LokasiKonfirmasiPage({required this.posisiAwal, required this.jenis});

  @override
  State<_LokasiKonfirmasiPage> createState() => _LokasiKonfirmasiPageState();
}

class _LokasiKonfirmasiPageState extends State<_LokasiKonfirmasiPage> {
  late Position _posisi;
  bool _memuatUlang = false;
  final MapController _mapController = MapController();

  bool get _wajibDalamArea => widget.jenis == StatusAbsensi.hadir;

  @override
  void initState() {
    super.initState();
    _posisi = widget.posisiAwal;
  }

  Future<void> _ambilUlangLokasi() async {
    setState(() => _memuatUlang = true);
    try {
      final posisiBaru = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() => _posisi = posisiBaru);
      _mapController.move(ll.LatLng(_posisi.latitude, _posisi.longitude), 17);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal memperbarui lokasi, coba lagi")),
      );
    } finally {
      if (mounted) setState(() => _memuatUlang = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titik = ll.LatLng(_posisi.latitude, _posisi.longitude);
    final akurasiOk = _posisi.accuracy <= 30;
    final diDalamArea = GeofenceKebun.isInside(_posisi.latitude, _posisi.longitude);

    final bolehLanjut = !_wajibDalamArea || diDalamArea;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Konfirmasi Lokasi", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: titik, initialZoom: 17),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ppks.kawalkebun',
                    ),
                    PolygonLayer(polygons: [
                      Polygon(
                        points: GeofenceKebun.batasKebun,
                        color: Colors.green.withOpacity(0.12),
                        borderColor: Colors.green,
                        borderStrokeWidth: 2,
                      ),
                    ]),
                    CircleLayer(circles: [
                      CircleMarker(
                        point: titik,
                        radius: _posisi.accuracy,
                        useRadiusInMeter: true,
                        color: Colors.green.withOpacity(0.15),
                        borderColor: Colors.green.withOpacity(0.5),
                        borderStrokeWidth: 1.5,
                      ),
                    ]),
                    MarkerLayer(markers: [
                      Marker(
                        point: titik,
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.location_on,
                          color: (!_wajibDalamArea || diDalamArea) ? Colors.red : Colors.grey.shade700,
                          size: 46,
                        ),
                      ),
                    ]),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              akurasiOk ? Icons.gps_fixed : Icons.gps_not_fixed,
                              color: akurasiOk ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                akurasiOk
                                    ? "Lokasi terdeteksi (akurasi \u00b1${_posisi.accuracy.toStringAsFixed(0)} m)"
                                    : "Akurasi lemah (\u00b1${_posisi.accuracy.toStringAsFixed(0)} m) - coba di area terbuka",
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: bolehLanjut ? Colors.green : Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              bolehLanjut ? Icons.check_circle : Icons.block,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                !_wajibDalamArea
                                    ? (diDalamArea
                                        ? "Di dalam area kerja"
                                        : "Di luar area kerja \u2014 tetap bisa lanjut (Izin/Sakit)")
                                    : (diDalamArea
                                        ? "Di dalam area kerja"
                                        : "Di luar area kerja - absensi Hadir tidak bisa dilanjutkan"),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${_posisi.latitude.toStringAsFixed(6)}, ${_posisi.longitude.toStringAsFixed(6)}",
                        style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'monospace'),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _memuatUlang ? null : _ambilUlangLokasi,
                      icon: _memuatUlang
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 18),
                      label: const Text("Perbarui"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bolehLanjut ? Colors.green : Colors.grey,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: bolehLanjut ? () => Navigator.pop(context, _posisi) : null,
                    icon: Icon(bolehLanjut ? Icons.check_circle : Icons.block, color: Colors.white),
                    label: Text(
                      bolehLanjut ? "Lokasi Sudah Benar, Lanjutkan" : "Di Luar Area Kerja",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ============================================================
   DIALOG PROSES (checklist)
   ============================================================ */
class _ProsesAbsenDialog extends StatefulWidget {
  final Future<void> Function() proses;
  const _ProsesAbsenDialog({required this.proses});

  @override
  State<_ProsesAbsenDialog> createState() => _ProsesAbsenDialogState();
}

class _ProsesAbsenDialogState extends State<_ProsesAbsenDialog> {
  int _stepAktif = 0;
  final List<String> _label = const [
    "Lokasi terverifikasi",
    "Wajah terverifikasi",
    "Menyimpan data absensi",
  ];

  @override
  void initState() {
    super.initState();
    _jalankan();
  }

  Future<void> _jalankan() async {
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _stepAktif = 1);

    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _stepAktif = 2);

    try {
      await widget.proses();
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_label.length, (i) {
            final selesai = i < _stepAktif;
            final aktif = i == _stepAktif;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  selesai
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
                      : aktif
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                            )
                          : Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    _label[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: (selesai || aktif) ? FontWeight.w600 : FontWeight.normal,
                      color: (selesai || aktif) ? Colors.black87 : Colors.black38,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/* ============================================================
   HALAMAN SUKSES
   ============================================================ */
class _AbsenSuksesPage extends StatelessWidget {
  final Position posisi;
  final RiwayatAbsensi? status;
  final VoidCallback onSelesai;

  const _AbsenSuksesPage({
    required this.posisi,
    required this.status,
    required this.onSelesai,
  });

  @override
  Widget build(BuildContext context) {
    final (warna, ikon, label) = infoStatusAbsensi(status?.status ?? StatusAbsensi.hadir);
    final punyaJam = status != null && (status!.status == StatusAbsensi.hadir || status!.status == StatusAbsensi.telat);
    final titik = ll.LatLng(posisi.latitude, posisi.longitude);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(initialCenter: titik, initialZoom: 16),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.ppks.kawalkebun',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: titik,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: warna.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(ikon, color: warna, size: 56),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Absen Berhasil Dicatat",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: warna.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        punyaJam ? "$label \u00b7 ${status!.jam.substring(0, 5)}" : label,
                        style: TextStyle(color: warna, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: onSelesai,
                        child: const Text("Selesai", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}