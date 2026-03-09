import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'dashboard.dart';

class PerawatanKastrasiPage extends StatefulWidget {
  const PerawatanKastrasiPage({super.key});

  @override
  State<PerawatanKastrasiPage> createState() =>
      _PerawatanKastrasiPageState();
}

class _PerawatanKastrasiPageState
    extends State<PerawatanKastrasiPage> {
  final TextEditingController _tanggalController =
      TextEditingController();
  final TextEditingController _jumlahController =
      TextEditingController();
  final TextEditingController _biayaController =
      TextEditingController();
  final TextEditingController _lainnyaController =
      TextEditingController();

  Future<void> _pilihTanggal(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _tanggalController.text =
            "${picked.day}-${picked.month}-${picked.year}";
      });
    }
  }

  // ===============================
  // 🔹 SIMPAN KE SQLITE
  // ===============================
  Future<void> _simpanData() async {
    if (_tanggalController.text.isEmpty ||
        _jumlahController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lengkapi semua data terlebih dahulu"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime parsedDate =
        DateFormat('d-M-yyyy').parse(_tanggalController.text);

    final dataBaru = {
      "type": "kastrasi",
      "tanggal": DateFormat('yyyy-MM-dd').format(parsedDate),
      "jumlah": double.tryParse(_jumlahController.text) ?? 0,
      "biaya": double.tryParse(_biayaController.text) ?? 0,
      "lainnya": double.tryParse(_lainnyaController.text) ?? 0,
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
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFFFC107)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Text("Perawatan Kastrasi",
                style: TextStyle(
                    color: Color(0xFF33691E),
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Text("Selanjutnya selesai",
                style:
                    TextStyle(color: Colors.brown, fontSize: 13)),
            const SizedBox(height: 20),

            const Text("Tanggal Kastrasi",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _tanggalController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: "Pilih Tanggal Kastrasi",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pilihTanggal(context),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            const Text("Jumlah Pohon",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _jumlahController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText:
                    "Masukkan jumlah pohon dikastrasi",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            const Text("Total Biaya Kastrasi",
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _biayaController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: "Rp ",
                hintText: "Total Biaya Kastrasi",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.yellow.shade100,
                        foregroundColor: Colors.black),
                    child: const Text("Kembali"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _simpanData,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                    child: const Text("Kirim"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
