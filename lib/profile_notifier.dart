import 'dart:typed_data';
import 'package:flutter/material.dart';

class ProfileNotifier {
  // Nama user
  final ValueNotifier<String> nama = ValueNotifier('User');
  // Foto lokal (MemoryImage)
  final ValueNotifier<Uint8List?> fotoLocal = ValueNotifier(null);

  // Update semua nilai
  void update({String? newNama, Uint8List? newFoto}) {
    if (newNama != null) nama.value = newNama;
    if (newFoto != null) fotoLocal.value = newFoto;
  }
}

// Singleton supaya bisa diakses dari mana saja
final profileNotifier = ProfileNotifier();
