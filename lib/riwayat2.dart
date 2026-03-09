import 'package:flutter/material.dart';

class Riwayat2Page extends StatefulWidget {
  const Riwayat2Page({super.key});

  @override
  State<Riwayat2Page> createState() => _Riwayat2PageState();
}

class _Riwayat2PageState extends State<Riwayat2Page> {
  String selectedJenis = "Semua Jenis";

  final List<String> jenisList = [
    "Semua Jenis",
    "Pencapaian Program",
    "Mesin Penghasil Sawit Poin",
    "Pembelian",
    "Transfer Sawit Point",
    "Pengembalian Sawit Point",
    "Aktivitas",
    "Undang Teman",
    "Mendaftarkan Pengguna",
    "Lainnya",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD36E),
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        title: const Text(
          "Filter Riwayat",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _headerCard(),
            const SizedBox(height: 16),
            _jenisCard(),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Colors.green,
            Color(0xFF2E7D32),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Pilih Jenis Riwayat",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Tentukan jenis data yang ingin ditampilkan",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ================= CARD JENIS =================
  Widget _jenisCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var item in jenisList) _radioItem(item),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.pop(context, selectedJenis);
                },
                child: const Text(
                  "Terapkan Filter",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ================= RADIO ITEM =================
  Widget _radioItem(String item) {
    final isSelected = selectedJenis == item;

    return InkWell(
      onTap: () {
        setState(() => selectedJenis = item);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 231, 231, 231).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: item,
              groupValue: selectedJenis,
              activeColor: Colors.green,
              onChanged: (value) {
                setState(() => selectedJenis = value!);
              },
            ),
            Expanded(
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
