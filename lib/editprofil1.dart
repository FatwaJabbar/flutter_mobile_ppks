import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart'; // ⭐ SESSION

class EditProfilPage extends StatefulWidget {
  const EditProfilPage({super.key});

  @override
  State<EditProfilPage> createState() => _EditProfilPageState();
}

class _EditProfilPageState extends State<EditProfilPage> {
  final namaC = TextEditingController();
  final bioC = TextEditingController();
  final telpC = TextEditingController();

  Uint8List? fotoBaru;
  Uint8List? fotoAwal;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (UserSession.userId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(UserSession.userId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      namaC.text = data['nama'] ?? '';
      bioC.text = data['bio'] ?? '';
      telpC.text = data['telp'] ?? '';

      final fotoBase64 = data['fotoBase64'];
      if (fotoBase64 != null && fotoBase64.toString().isNotEmpty) {
        fotoAwal = base64Decode(fotoBase64);
      }
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
    );

    if (file != null) {
      fotoBaru = await file.readAsBytes();
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (isSaving) return;

    if (UserSession.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User tidak ditemukan")),
      );
      return;
    }

    try {
      setState(() => isSaving = true);

      final Map<String, dynamic> data = {
        'nama': namaC.text.trim(),
        'bio': bioC.text.trim(),
        'telp': telpC.text.trim(),
      };

      if (fotoBaru != null) {
        data['fotoBase64'] = base64Encode(fotoBaru!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(UserSession.userId)
          .set(data, SetOptions(merge: true));

      // 🔥 UPDATE SESSION LANGSUNG
      UserSession.nama = namaC.text.trim();
      UserSession.bio = bioC.text.trim();
      UserSession.telp = telpC.text.trim();
      if (fotoBaru != null) {
        UserSession.fotoBase64 = base64Encode(fotoBaru!);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan: $e")),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider avatar;
    if (fotoBaru != null) {
      avatar = MemoryImage(fotoBaru!);
    } else if (fotoAwal != null) {
      avatar = MemoryImage(fotoAwal!);
    } else if ((UserSession.fotoGoogleUrl ?? '').isNotEmpty) {
      avatar = NetworkImage(UserSession.fotoGoogleUrl!);
    } else {
      avatar = const AssetImage('assets/images/default_avatar.png');
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text(
          "Edit Profil",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                backgroundImage: avatar,
              ),
            ),
            const SizedBox(height: 30),
            _field("Nama", namaC),
            _field("Bio", bioC),
            _field("No HP", telpC, isNumber: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSaving ? null : _save,
              child: Text(isSaving ? "Menyimpan..." : "Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 6),
      child: TextField(
        controller: c,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: const InputDecoration(
          filled: true,
          fillColor: Colors.white,
        ).copyWith(labelText: label),
      ),
    );
  }
}
