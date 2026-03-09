// file: akun1.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'editprofil1.dart';
import 'login_page.dart';
import 'katasandi1.dart';
import 'tambahpanen.dart';
import 'user_session.dart';

class AccountPage1 extends StatefulWidget {
  const AccountPage1({super.key});

  @override
  State<AccountPage1> createState() => _AccountPage1State();
}

class _AccountPage1State extends State<AccountPage1> {
  late String nama;
  late String bio;
  late String telp;
  Uint8List? fotoLocal;
  String? fotoGoogleUrl;

  // ===== TAMBAHAN UNTUK TAMPIL ALAMAT =====
  String? provinsiUser;
  String? kotaUser;
  String? jalanUser;

  // ================= 38 PROVINSI =================
  final List<String> provinsiList = [
    "Aceh","Sumatera Utara","Sumatera Barat","Riau","Jambi",
    "Sumatera Selatan","Bengkulu","Lampung","Kepulauan Bangka Belitung",
    "Kepulauan Riau","DKI Jakarta","Jawa Barat","Jawa Tengah",
    "DI Yogyakarta","Jawa Timur","Banten","Bali",
    "Nusa Tenggara Barat","Nusa Tenggara Timur",
    "Kalimantan Barat","Kalimantan Tengah","Kalimantan Selatan",
    "Kalimantan Timur","Kalimantan Utara",
    "Sulawesi Utara","Sulawesi Tengah","Sulawesi Selatan",
    "Sulawesi Tenggara","Gorontalo","Sulawesi Barat",
    "Maluku","Maluku Utara",
    "Papua","Papua Barat","Papua Selatan",
    "Papua Tengah","Papua Pegunungan","Papua Barat Daya",
  ];

  // ================= DATA KOTA & JALAN =================
  final Map<String, Map<String, List<String>>> alamatData = {

    // ================= SUMATERA =================
    "Aceh": {
      "Banda Aceh": ["Jl. Utama"],
      "Langsa": ["Jl. Utama"],
      "Lhokseumawe": ["Jl. Utama"],
      "Sabang": ["Jl. Utama"],
      "Subulussalam": ["Jl. Utama"],
    },
    "Sumatera Utara": {
      "Binjai": ["Jl. Utama"],
      "Gunungsitoli": ["Jl. Utama"],
      "Medan": ["Jl. Utama"],
      "Padangsidimpuan": ["Jl. Utama"],
      "Pematangsiantar": ["Jl. Utama"],
      "Sibolga": ["Jl. Utama"],
      "Tanjungbalai": ["Jl. Utama"],
      "Tebing Tinggi": ["Jl. Utama"],
    },
    "Sumatera Barat": {
      "Bukittinggi": ["Jl. Utama"],
      "Padang": ["Jl. Utama"],
      "Padang Panjang": ["Jl. Utama"],
      "Pariaman": ["Jl. Utama"],
      "Payakumbuh": ["Jl. Utama"],
      "Sawahlunto": ["Jl. Utama"],
      "Solok": ["Jl. Utama"],
    },
    "Riau": {
      "Dumai": ["Jl. Utama"],
      "Pekanbaru": ["Jl. Utama"],
    },
    "Kepulauan Riau": {
      "Batam": ["Jl. Utama"],
      "Tanjungpinang": ["Jl. Utama"],
    },
    "Jambi": {
      "Jambi": ["Jl. Utama"],
      "Sungai Penuh": ["Jl. Utama"],
    },
    "Bengkulu": {
      "Bengkulu": ["Jl. Utama"],
    },
    "Sumatera Selatan": {
      "Lubuklinggau": ["Jl. Utama"],
      "Pagar Alam": ["Jl. Utama"],
      "Palembang": ["Jl. Utama"],
      "Prabumulih": ["Jl. Utama"],
    },
    "Kepulauan Bangka Belitung": {
      "Pangkalpinang": ["Jl. Utama"],
    },
    "Lampung": {
      "Bandar Lampung": ["Jl. Utama"],
      "Metro": ["Jl. Utama"],
    },

    // ================= JAWA =================
    "DKI Jakarta": {
      "Jakarta Pusat": ["Jl. Utama"],
      "Jakarta Barat": ["Jl. Utama"],
      "Jakarta Timur": ["Jl. Utama"],
      "Jakarta Selatan": ["Jl. Utama"],
      "Jakarta Utara": ["Jl. Utama"],
    },
    "Jawa Barat": {
      "Bandung": ["Jl. Utama"],
      "Banjar": ["Jl. Utama"],
      "Bekasi": ["Jl. Utama"],
      "Bogor": ["Jl. Utama"],
      "Cimahi": ["Jl. Utama"],
      "Cirebon": ["Jl. Utama"],
      "Depok": ["Jl. Utama"],
      "Sukabumi": ["Jl. Utama"],
      "Tasikmalaya": ["Jl. Utama"],
    },
    "Banten": {
      "Tangerang": ["Jl. Utama"],
      "Tangerang Selatan": ["Jl. Utama"],
      "Serang": ["Jl. Utama"],
      "Cilegon": ["Jl. Utama"],
    },
    "Jawa Tengah": {
      "Magelang": ["Jl. Utama"],
      "Pekalongan": ["Jl. Utama"],
      "Salatiga": ["Jl. Utama"],
      "Semarang": ["Jl. Utama"],
      "Surakarta": ["Jl. Utama"],
      "Tegal": ["Jl. Utama"],
    },
    "DI Yogyakarta": {
      "Yogyakarta": ["Jl. Utama"],
    },
    "Jawa Timur": {
      "Batu": ["Jl. Utama"],
      "Blitar": ["Jl. Utama"],
      "Kediri": ["Jl. Utama"],
      "Madiun": ["Jl. Utama"],
      "Malang": ["Jl. Utama"],
      "Mojokerto": ["Jl. Utama"],
      "Pasuruan": ["Jl. Utama"],
      "Probolinggo": ["Jl. Utama"],
      "Surabaya": ["Jl. Utama"],
    },

    // ================= BALI & NT =================
    "Bali": {
      "Denpasar": ["Jl. Utama"],
    },
    "Nusa Tenggara Barat": {
      "Mataram": ["Jl. Utama"],
      "Bima": ["Jl. Utama"],
    },
    "Nusa Tenggara Timur": {
      "Kupang": ["Jl. Utama"],
    },

    // ================= KALIMANTAN =================
    "Kalimantan Barat": {
      "Pontianak": ["Jl. Utama"],
      "Singkawang": ["Jl. Utama"],
    },
    "Kalimantan Tengah": {
      "Palangkaraya": ["Jl. Utama"],
    },
    "Kalimantan Selatan": {
      "Banjarmasin": ["Jl. Utama"],
      "Banjarbaru": ["Jl. Utama"],
    },
    "Kalimantan Timur": {
      "Balikpapan": ["Jl. Utama"],
      "Bontang": ["Jl. Utama"],
      "Samarinda": ["Jl. Utama"],
    },
    "Kalimantan Utara": {
      "Tarakan": ["Jl. Utama"],
    },

    // ================= SULAWESI =================
    "Sulawesi Utara": {
      "Bitung": ["Jl. Utama"],
      "Kotamobagu": ["Jl. Utama"],
      "Manado": ["Jl. Utama"],
      "Tomohon": ["Jl. Utama"],
    },
    "Gorontalo": {
      "Gorontalo": ["Jl. Utama"],
    },
    "Sulawesi Tengah": {
      "Palu": ["Jl. Utama"],
    },
    "Sulawesi Selatan": {
      "Makassar": ["Jl. Utama"],
      "Palopo": ["Jl. Utama"],
      "Parepare": ["Jl. Utama"],
    },
    "Sulawesi Tenggara": {
      "Kendari": ["Jl. Utama"],
      "Baubau": ["Jl. Utama"],
    },

    // ================= MALUKU & PAPUA =================
    "Maluku": {
      "Ambon": ["Jl. Utama"],
      "Tual": ["Jl. Utama"],
    },
    "Maluku Utara": {
      "Ternate": ["Jl. Utama"],
      "Tidore Kepulauan": ["Jl. Utama"],
    },
    "Papua": {
      "Jayapura": ["Jl. Utama"],
    },
    "Papua Barat": {
      "Sorong": ["Jl. Utama"],
    },
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    nama = UserSession.nama ?? 'User';
    bio = UserSession.bio ?? '';
    telp = UserSession.telp ?? '';
    fotoGoogleUrl = UserSession.fotoGoogleUrl;
    final fotoBase64 = UserSession.fotoBase64 ?? '';

    if (fotoBase64.isNotEmpty) {
      fotoLocal = base64Decode(fotoBase64);
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(UserSession.userId)
        .get();

    if (doc.exists) {
      provinsiUser = doc.data()?['provinsi'];
      kotaUser = doc.data()?['kota'];
      jalanUser = doc.data()?['jalan'];
    }

    setState(() {});
  }

  // ================= POPUP ALAMAT =================
  Future<void> _showAlamatDialog() async {
    String? selectedProvinsi;
    String? selectedKota;
    final jalanManualC = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {

            List<String> kotaList =
                selectedProvinsi == null
                    ? []
                    : alamatData[selectedProvinsi]?.keys.toList() ?? [];

            return AlertDialog(
              backgroundColor: const Color(0xFFFFF8E1),
              title: const Text("Isi Alamat"),
              content: SingleChildScrollView(
                child: Column(
                  children: [

                    DropdownButtonFormField<String>(
                      value: selectedProvinsi,
            items: provinsiList
                          .map((e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ))
                          .toList(),
                      decoration: const InputDecoration(
                        labelText: "Provinsi",
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          selectedProvinsi = val;
                          selectedKota = null;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    if (selectedProvinsi != null)
                      DropdownButtonFormField<String>(
                        value: selectedKota,
                        items: kotaList
                            .map((k) => DropdownMenuItem<String>(
                                  value: k,
                                  child: Text(k),
                                ))
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: "Kota",
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedKota = val;
                          });
                        },
                      ),

                    const SizedBox(height: 10),

                    if (selectedKota != null)
                      TextField(
                        controller: jalanManualC,
                        decoration: const InputDecoration(
                          labelText: "Nama Jalan / Detail",
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () async {

                    if (selectedProvinsi == null ||
                        selectedKota == null ||
                        jalanManualC.text.isEmpty) return;

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(UserSession.userId)
                        .set({
                      'provinsi': selectedProvinsi,
                      'kota': selectedKota,
                      'jalan': jalanManualC.text,
                    }, SetOptions(merge: true));

                    Navigator.pop(ctx);
                    _loadProfile();
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= LOGOUT =================
  Future<void> _logout(BuildContext context) async {
    final googleSignIn = GoogleSignIn();
    await FirebaseAuth.instance.signOut();
    if (UserSession.isGoogleUser) {
      await googleSignIn.signOut();
    }
    UserSession.clear();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider avatar;

    if (fotoLocal != null && fotoLocal!.isNotEmpty) {
      avatar = MemoryImage(fotoLocal!);
    } else if (fotoGoogleUrl != null && fotoGoogleUrl!.isNotEmpty) {
      avatar = NetworkImage(fotoGoogleUrl!);
    } else {
      avatar = const AssetImage('assets/images/default_avatar.png');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Akun Saya",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFE082), Color(0xFFFFC107)],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(radius: 45, backgroundImage: avatar),
                  const SizedBox(height: 10),
                  Text(nama,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text(bio),
                  Text("Telp: $telp"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfilPage(),
                        ),
                      );
                      if (result == true) _loadProfile();
                    },
                    child: const Text("Edit Profil"),
                  ),
                ],
              ),
            ),

            _menu(Icons.add_circle_outline, "Tambahkan Panen", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TambahPanenPage(),
                ),
              );
            }),

            _menu(Icons.location_on_outlined, "Alamat", _showAlamatDialog),

            if (provinsiUser != null &&
                kotaUser != null &&
                jalanUser != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "$jalanUser, $kotaUser, $provinsiUser",
                      ),
                    ),
                  ],
                ),
              ),

            if (!UserSession.isGoogleUser)
              _menu(Icons.lock_outline, "Kata Sandi", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KataSandi1(),
                  ),
                );
              }),

            _menu(Icons.logout, "Keluar",
                () => _showLogoutDialog(context)),
          ],
        ),
      ),
    );
  }

  Widget _menu(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(text),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8E1),
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            child: const Text("Keluar"),
          ),
        ],
      ),
    );
  }
}