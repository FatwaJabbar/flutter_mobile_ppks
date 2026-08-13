// file: absensi_pemilik.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'absensi_service.dart';
import 'absensi_models.dart';
import 'absensi_kick_helper.dart';
import 'deep_link_service.dart';
import 'user_session.dart';
import 'absensi_grafik_page.dart';

class AbsensiPemilikPage extends StatefulWidget {
  const AbsensiPemilikPage({super.key});

  @override
  State<AbsensiPemilikPage> createState() => _AbsensiPemilikPageState();
}

class _AbsensiPemilikPageState extends State<AbsensiPemilikPage> {
  AbsensiRoom? _room;
  bool _loading = true;
  final _namaKebunC = TextEditingController();
  bool _menyimpan = false;

  String get _uid => UserSession.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _namaOwner =>
      UserSession.nama ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Pemilik';

  @override
  void initState() {
    super.initState();
    _muatRoom();
  }

  Future<void> _muatRoom() async {
    final room = await AbsensiService.getRoomByOwner(_uid);
    setState(() {
      _room = room;
      _loading = false;
    });
  }

  Future<void> _buatRoom() async {
    if (_namaKebunC.text.trim().isEmpty) return;
    setState(() => _menyimpan = true);
    final room = await AbsensiService.createRoom(
      ownerId: _uid,
      ownerNama: _namaOwner,
      namaKebun: _namaKebunC.text.trim(),
    );
    setState(() {
      _room = room;
      _menyimpan = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Absensi - Pemilik", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_room == null ? _formBuatRoom() : _tampilanRoom(_room!)),
    );
  }

  Widget _formBuatRoom() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.groups, size: 80, color: Colors.green),
          const SizedBox(height: 10),
          const Text(
            "Anda belum memiliki room absensi.\nBuat room absensi Anda.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _namaKebunC,
            decoration: const InputDecoration(
              labelText: "Nama Room",
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
              onPressed: _menyimpan ? null : _buatRoom,
              child: _menyimpan
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("Buat Room Absensi"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tampilanRoom(AbsensiRoom room) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFC107)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.namaKebun,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Kode Akses", style: TextStyle(fontSize: 12)),
                Row(
                  children: [
                    Text(
                      room.kodeAkses,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: room.kodeAkses));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Kode akses disalin")),
                        );
                      },
                    ),
                  ],
                ),
                const Text(
                  "Bagikan kode ini ke pekerja agar bisa bergabung",
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final link = DeepLinkService.buatLink(room.kodeAkses);
                      Share.share(
                        "Yuk gabung absensi ${room.namaKebun}!\n"
                        "Buka link ini di HP yang sudah terpasang aplikasi:\n$link\n\n"
                        "Atau masukkan kode akses ini secara manual: ${room.kodeAkses}",
                      );
                    },
                    icon: const Icon(Icons.share, color: Colors.green, size: 18),
                    label: const Text(
                      "Bagikan Link Undangan",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text("Kehadiran Hari Ini",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          StreamBuilder<List<AnggotaAbsensi>>(
            stream: AbsensiService.streamAnggota(room.roomId),
            builder: (context, anggotaSnap) {
              final anggota = anggotaSnap.data ?? [];
              return StreamBuilder<List<RiwayatAbsensi>>(
                stream: AbsensiService.streamRiwayatHariIni(room.roomId),
                builder: (context, riwayatSnap) {
                  final riwayat = riwayatSnap.data ?? [];

                  if (anggota.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("Belum ada pekerja yang bergabung."),
                    );
                  }

                  final hadir = riwayat.where((r) => r.status == StatusAbsensi.hadir).length;
                  final telat = riwayat.where((r) => r.status == StatusAbsensi.telat).length;
                  final izin = riwayat.where((r) => r.status == StatusAbsensi.izin).length;
                  final sakit = riwayat.where((r) => r.status == StatusAbsensi.sakit).length;
                  final alpha = riwayat.where((r) => r.status == StatusAbsensi.alpha).length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _statChip("Hadir", hadir, Colors.green),
                          const SizedBox(width: 8),
                          _statChip("Telat", telat, Colors.orange),
                          const SizedBox(width: 8),
                          _statChip("Izin", izin, Colors.blueGrey),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _statChip("Sakit", sakit, Colors.redAccent),
                          const SizedBox(width: 8),
                          _statChip("Alpha", alpha, Colors.red.shade900),
                          const SizedBox(width: 8),
                          _statChip(
                            "Belum",
                            anggota.length - riwayat.length,
                            Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Column(
                        children: List.generate(anggota.length, (i) {
                          final a = anggota[i];
                          RiwayatAbsensi? r;
                          for (final x in riwayat) {
                            if (x.userId == a.userId) r = x;
                          }
                          return Padding(
                            padding: EdgeInsets.only(bottom: i == anggota.length - 1 ? 0 : 10),
                            child: _kartuAnggota(room.roomId, a, r),
                          );
                        }),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int jumlah, Color warna) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: warna.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: warna.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text("$jumlah",
                style: TextStyle(fontWeight: FontWeight.bold, color: warna, fontSize: 16)),
            Text(label, style: TextStyle(fontSize: 11, color: warna)),
          ],
        ),
      ),
    );
  }

  Widget _kartuAnggota(String roomId, AnggotaAbsensi a, RiwayatAbsensi? r) {
    final status = r?.status ?? StatusAbsensi.belum;
    final (warna, ikonStatus, labelDasar) = infoStatusAbsensi(status);
    final punyaJam = status == StatusAbsensi.hadir || status == StatusAbsensi.telat;
    final label = punyaJam ? "$labelDasar · ${r?.jam.substring(0, 5) ?? ''}" : labelDasar;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.withOpacity(0.12),
            child: const Icon(Icons.person, color: Colors.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.nama,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (r?.keterangan != null && r!.keterangan!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      r.keterangan!,
                      style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Grafik aktivitas harian (di dalam/luar area) -- selalu bisa
          // dilihat pemilik untuk memantau semua pekerja, tidak menunggu
          // pekerja checkout dulu (kalau belum checkout, datanya berjalan
          // sampai titik terakhir yang tercatat).
          IconButton(
            icon: const Icon(Icons.insights, color: Colors.green, size: 20),
            tooltip: "Lihat grafik aktivitas hari ini",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AbsensiGrafikPage(roomId: roomId, userId: a.userId, nama: a.nama),
              ),
            ),
          ),
          if (r?.lat != null && r?.lng != null)
            IconButton(
              icon: const Icon(Icons.location_on, color: Colors.green, size: 20),
              tooltip: "Lihat lokasi absen",
              onPressed: () async {
                final url = Uri.parse('https://www.google.com/maps?q=${r!.lat},${r.lng}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: warna.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: warna.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ikonStatus, size: 14, color: warna),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: warna, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.person_remove_alt_1, color: Colors.redAccent, size: 20),
            tooltip: "Keluarkan dari room",
            onPressed: () => tampilkanDialogKick(
              context: context,
              roomId: roomId,
              anggota: a,
            ),
          ),
        ],
      ),
    );
  }
}