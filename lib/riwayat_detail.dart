import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RiwayatDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String sumber;

  const RiwayatDetailPage({
    super.key,
    required this.data,
    required this.sumber,
  });

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _normalizeType(dynamic value) {
    return (value ?? '')
        .toString()
        .toLowerCase()
        .trim()
        .replaceAll(" ", "");
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('id');

    final type = _normalizeType(data['type']);
    final tanggal = data['tanggal']?.toString() ?? '-';

    String title;
    switch (type) {
      case 'panen':
        title = "Detail Panen";
        break;
      case 'pembabatan':
        title = "Detail Pembabatan";
        break;
      case 'pemupukan':
        title = "Detail Pemupukan";
        break;
      case 'penunasan':
        title = "Detail Penunasan";
        break;
      case 'penyemprotan':
        title = "Detail Penyemprotan";
        break;
      case 'kastrasi':
        title = "Detail Kastrasi";
        break;
      case 'sanitasi':
        title = "Sanitasi";
        break;
      default:
        title = "Detail Perawatan";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFECB3),
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _headerCard(type),
            const SizedBox(height: 16),
            _detailCard(
              children: [
                _premiumItem(
                  label: "Tanggal",
                  value: tanggal,
                  icon: Icons.calendar_today,
                ),
                const Divider(height: 1),

                /// ================= PANEN =================
                if (type == 'panen') ...[
                  _premiumItem(
                    label: "Berat Panen",
                    value:
                        "${formatter.format(_toDouble(data['berat']))} Kg",
                    icon: Icons.scale,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Harga TBS",
                    value:
                        "Rp ${formatter.format(_toDouble(data['harga']))}",
                    icon: Icons.attach_money,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Upah Panen",
                    value:
                        "Rp ${formatter.format(_toDouble(data['biaya']))}",
                    icon: Icons.payments_outlined,
                  ),
                ],

                /// ================= PEMBABATAN =================
                if (type == 'pembabatan') ...[
                  _premiumItem(
                    label: "Luas Area",
                    value:
                        "${formatter.format(_toDouble(data['jumlah']))} m²",
                    icon: Icons.crop_square,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Biaya Pembabatan",
                    value:
                        "Rp ${formatter.format(_toDouble(data['biaya']))}",
                    icon: Icons.payments,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Biaya Lainnya",
                    value:
                        "Rp ${formatter.format(_toDouble(data['lainnya']))}",
                    icon: Icons.money_off,
                  ),
                ],

                /// ================= PEMUPUKAN =================
                if (type == 'pemupukan') ...[
                  _premiumItem(
                    label: "Jenis Pupuk",
                    value: data['jenisPupuk']?.toString() ?? '-',
                    icon: Icons.eco,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Jumlah",
                    value:
                        "${formatter.format(_toDouble(data['jumlah']))} Kg",
                    icon: Icons.inventory,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Total Biaya",
                    value:
                        "Rp ${formatter.format(_toDouble(data['biaya']) + _toDouble(data['lainnya']))}",
                    icon: Icons.payments,
                  ),
                ],

                /// ================= PENUNASAN =================
                if (type == 'penunasan') ...[
                  _premiumItem(
                    label: "Jumlah Pohon",
                    value:
                        "${formatter.format(_toDouble(data['jumlah']))} Pohon",
                    icon: Icons.park,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Total Biaya",
                    value:
                        "Rp ${formatter.format(_toDouble(data['biaya']) + _toDouble(data['lainnya']))}",
                    icon: Icons.payments,
                  ),
                ],

                /// ================= PENYEMPROTAN =================
                if (type == 'penyemprotan') ...[
                  _premiumItem(
                    label: "Jenis Cairan",
                    value: data['jenisPupuk']?.toString() ?? '-',
                    icon: Icons.water_drop,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Total Biaya",
                    value:
                        "Rp ${formatter.format(_toDouble(data['biaya']) + _toDouble(data['lainnya']))}",
                    icon: Icons.payments,
                  ),
                ],

                /// ================= KASTRASI =================
                if (type == 'kastrasi') ...[
                  _premiumItem(
                    label: "Jumlah Pohon",
                    value:
                        "${formatter.format(_toDouble(data['jumlah']))} Pohon",
                    icon: Icons.park,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Total Biaya",
                    value:
                        "Rp ${formatter.format(_toDouble(data['biaya']) + _toDouble(data['lainnya']))}",
                    icon: Icons.payments,
                  ),
                ],

                /// ================= SANITASI =================
                if (type == 'sanitasi') ...[
                  _premiumItem(
                    label: "Lokasi Area",
                    value: data['jenisPupuk']?.toString() ?? '-',
                    icon: Icons.location_on,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Biaya Sanitasi",
                    value:
                        "Rp ${formatter.format(_toDouble(data['biaya']))}",
                    icon: Icons.cleaning_services,
                  ),
                  const Divider(height: 1),
                  _premiumItem(
                    label: "Biaya Lainnya",
                    value:
                        "Rp ${formatter.format(_toDouble(data['lainnya']))}",
                    icon: Icons.payments,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(String type) {
    String text;

    switch (type) {
      case 'panen':
        text = "Informasi Panen";
        break;
      case 'pembabatan':
        text = "Informasi Pembabatan";
        break;
      case 'pemupukan':
        text = "Informasi Pemupukan";
        break;
      case 'penunasan':
        text = "Informasi Penunasan";
        break;
      case 'penyemprotan':
        text = "Informasi Penyemprotan";
        break;
      case 'kastrasi':
        text = "Informasi Kastrasi";
        break;
      case 'sanitasi':
        text = "Informasi Sanitasi";
        break;
      default:
        text = "Informasi Perawatan";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Colors.green, Color(0xFF2E7D32)],
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _premiumItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
