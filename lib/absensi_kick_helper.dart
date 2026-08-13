// file: absensi_kick_helper.dart
import 'package:flutter/material.dart';
import 'absensi_models.dart';
import 'absensi_service.dart';

/// Menampilkan dialog konfirmasi lalu mengeluarkan [anggota] dari room
/// [roomId] kalau pemilik menekan "Keluarkan". Pekerja yang di-kick akan
/// perlu memasukkan Kode Akses lagi untuk bisa bergabung kembali.
Future<void> tampilkanDialogKick({
  required BuildContext context,
  required String roomId,
  required AnggotaAbsensi anggota,
}) async {
  final konfirmasi = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFFFF8E1),
      title: const Text("Keluarkan Pekerja?"),
      content: Text(
        'Yakin ingin mengeluarkan "${anggota.nama}" dari ruang absensi ini? '
        'Pekerja perlu memasukkan Kode Akses lagi untuk bisa bergabung kembali.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Keluarkan", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (konfirmasi != true) return;

  await AbsensiService.kickAnggota(roomId: roomId, userId: anggota.userId);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${anggota.nama}" telah dikeluarkan dari room')),
    );
  }
}