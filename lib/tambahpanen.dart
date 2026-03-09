import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'catatrawat.dart';
import 'database_helper.dart';
import 'dashboard.dart';
import 'user_session.dart';

class TambahPanenPage extends StatefulWidget {
  const TambahPanenPage({super.key});

  @override
  State<TambahPanenPage> createState() => _TambahPanenPageState();
}

class _TambahPanenPageState extends State<TambahPanenPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _beratController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _upahController = TextEditingController();

  double hargaPerKg = 0;
  String? provinsiUser;

  @override
  void initState() {
    super.initState();
    _loadProvinsiUser();
    _beratController.addListener(_isiHargaOtomatis);
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _beratController.dispose();
    _hargaController.dispose();
    _upahController.dispose();
    super.dispose();
  }

  // ================= LOAD PROVINSI USER =================
  Future<void> _loadProvinsiUser() async {
    final userId = UserSession.userId;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    if (!userDoc.exists) return;

    provinsiUser = userDoc.data()?['provinsi'];
  }

  // ================= LOAD HARGA BERDASARKAN TANGGAL =================
  Future<void> _loadHargaByTanggal(DateTime tanggal) async {
    if (provinsiUser == null) return;

    final int tahun = tanggal.year;
    final int bulan = tanggal.month;

    try {
      // Cari harga bulan itu
      final snapshot = await FirebaseFirestore.instance
          .collection('tbs_harga')
          .where('provinsi', isEqualTo: provinsiUser)
          .where('tahun', isEqualTo: tahun)
          .where('bulan', isEqualTo: bulan)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        hargaPerKg = (snapshot.docs.first.data()['harga'] as num).toDouble();
      } else {
        // fallback: ambil harga terbaru sebelum bulan itu
        final fallbackSnapshot = await FirebaseFirestore.instance
            .collection('tbs_harga')
            .where('provinsi', isEqualTo: provinsiUser)
            .where('tahun', isLessThanOrEqualTo: tahun)
            .orderBy('tahun', descending: true)
            .orderBy('bulan', descending: true)
            .limit(1)
            .get();

        if (fallbackSnapshot.docs.isNotEmpty) {
          hargaPerKg =
              (fallbackSnapshot.docs.first.data()['harga'] as num).toDouble();
        } else {
          hargaPerKg = 0;
        }
      }

      _isiHargaOtomatis();
    } catch (e) {
      print("Error load harga: $e");
      hargaPerKg = 0;
      _hargaController.clear();
    }
  }

  // ================= AUTO HITUNG =================
  void _isiHargaOtomatis() {
    if (hargaPerKg <= 0) return;

    final beratText = _beratController.text;
    if (beratText.isEmpty) return;

    final berat = double.tryParse(beratText) ?? 0;

    if (berat > 0) {
      final total = hargaPerKg;
      _hargaController.text =
          NumberFormat("#,##0", "id_ID").format(total.toInt());
    } else {
      _hargaController.clear();
    }
  }

  // ================= PILIH TANGGAL =================
  Future<void> _pilihTanggal() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      await _loadHargaByTanggal(picked);
    }
  }

  double _parseNumber(String text) {
    return double.tryParse(text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
  }

  // ================= SIMPAN DATA (SQLITE) =================
  Future<void> _simpanData() async {
    if (!_formKey.currentState!.validate()) return;

    final berat = double.tryParse(_beratController.text) ?? 0;
    final harga = _parseNumber(_hargaController.text);
    final upah = _parseNumber(_upahController.text);

    final Map<String, dynamic> dataBaru = {
      'type': 'panen',
      'tanggal': _tanggalController.text,
      'berat': berat,
      'harga': harga,
      'biaya': upah,
      'lainnya': 0,
      'jenisPupuk': null,
      'jumlah': null,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await DBHelper.insert(dataBaru);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Data panen tersimpan"),
        backgroundColor: Colors.green,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const DashboardPage(initialIndex: 1),
      ),
      (route) => false,
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFECB3),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Tambahkan Panen"),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Tambahkan Panen Anda",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Isi data panen dengan benar",
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Text("Tanggal Panen"),
              const SizedBox(height: 6),
              TextFormField(
                controller: _tanggalController,
                readOnly: true,
                onTap: _pilihTanggal,
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (val) =>
                    (val ?? '').isEmpty ? "Pilih tanggal panen" : null,
              ),
              const SizedBox(height: 16),
              const Text("Berat Total TBS (Kg)"),
              const SizedBox(height: 6),
              TextFormField(
                controller: _beratController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFFFE082),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (val) =>
                    (val ?? '').isEmpty ? "Masukkan berat TBS" : null,
              ),
              const SizedBox(height: 16),
              const Text("Harga TBS (Rp/Kg)"),
              const SizedBox(height: 6),
              TextFormField(
                controller: _hargaController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsFormatter(),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFFFD54F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (val) =>
                    (val ?? '').isEmpty ? "Masukkan harga" : null,
              ),
              const SizedBox(height: 16),
              const Text("Upah Panen"),
              const SizedBox(height: 6),
              TextFormField(
                controller: _upahController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  ThousandsFormatter(),
                ],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFFFC107),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (val) =>
                    (val ?? '').isEmpty ? "Masukkan upah panen" : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _simpanData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Simpan Panen"),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.local_florist, color: Colors.green),
                  label: const Text(
                    "Catat Rawat",
                    style: TextStyle(color: Colors.green),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CatatRawatPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThousandsFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final clean = newValue.text.replaceAll('.', '');
    final number = int.tryParse(clean);
    if (number == null) return oldValue;

    final newText = _formatter.format(number);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}