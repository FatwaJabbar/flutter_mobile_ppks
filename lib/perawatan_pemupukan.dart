import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'dashboard.dart';

// Formatter ribuan
class ThousandFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String numericString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericString.isEmpty) return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    String formatted = _formatter.format(int.parse(numericString));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PerawatanPemupukanPage extends StatefulWidget {
  const PerawatanPemupukanPage({super.key});

  @override
  State<PerawatanPemupukanPage> createState() =>
      _PerawatanPemupukanPageState();
}

class _PerawatanPemupukanPageState extends State<PerawatanPemupukanPage> {
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _jumlahController = TextEditingController();
  final TextEditingController _biayaController = TextEditingController();
  final TextEditingController _lainnyaController = TextEditingController();

  String? _jenisPupuk;
  bool _tidakAdaBiayaLainnya = false;

  // PARSE NUMBER YANG BENAR
  double _parseNumber(String text) {
    // Hapus semua karakter selain angka dan titik
    String clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0;
  }

  Future<void> _pilihTanggal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _tanggalController.text = "${picked.day}-${picked.month}-${picked.year}";
      });
    }
  }

  Future<void> _simpanData() async {
    if (_tanggalController.text.isEmpty ||
        _jenisPupuk == null ||
        _jumlahController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lengkapi semua data terlebih dahulu"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime parsedDate = DateFormat('d-M-yyyy').parse(_tanggalController.text);

    final dataBaru = {
      "type": "pemupukan",
      "tanggal": DateFormat('yyyy-MM-dd').format(parsedDate),
      "jenisPupuk": _jenisPupuk,
      "jumlah": _parseNumber(_jumlahController.text),
      "biaya": _parseNumber(_biayaController.text),
      "lainnya": _tidakAdaBiayaLainnya ? 0 : _parseNumber(_lainnyaController.text),
      "createdAt": DateTime.now().toIso8601String(),
    };

    await DBHelper.insert(dataBaru);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Data berhasil disimpan!"),
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

  @override
  void dispose() {
    _tanggalController.dispose();
    _jumlahController.dispose();
    _biayaController.dispose();
    _lainnyaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Catat Rawat",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFFFC107)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Perawatan Pemupukan",
                style: TextStyle(
                  color: Color(0xFF33691E),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text("Tanggal Perawatan", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _tanggalController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: "Pilih Tanggal Perawatan",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pilihTanggal(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text("Jenis Pupuk", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _jenisPupuk,
                    hint: const Text("Pilih Jenis Pupuk"),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "Organik", child: Text("Organik")),
                      DropdownMenuItem(value: "NPK", child: Text("NPK")),
                      DropdownMenuItem(value: "Urea", child: Text("Urea")),
                      DropdownMenuItem(value: "Kompos", child: Text("Kompos")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _jenisPupuk = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Jumlah Kg", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _jumlahController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandFormatter()],
                decoration: InputDecoration(
                  hintText: "Total Berat Pupuk (Kg)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text("Total Biaya Perawatan", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _biayaController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandFormatter()],
                decoration: InputDecoration(
                  prefixText: "Rp ",
                  hintText: "Total Biaya Perawatan",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Biaya Lainnya", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      const Text("Tidak Ada"),
                      Switch(
                        value: _tidakAdaBiayaLainnya,
                        onChanged: (value) {
                          setState(() {
                            _tidakAdaBiayaLainnya = value;
                            if (value) {
                              _lainnyaController.text = "0";
                            } else {
                              _lainnyaController.clear();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!_tidakAdaBiayaLainnya)
                TextField(
                  controller: _lainnyaController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandFormatter()],
                  decoration: InputDecoration(
                    prefixText: "Rp ",
                    hintText: "Total Biaya Lainnya",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow.shade100,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text("Kembali"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _simpanData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Kirim"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}