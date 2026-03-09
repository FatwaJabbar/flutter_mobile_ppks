import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_session.dart';

class DokumentasiPage extends StatefulWidget {
  const DokumentasiPage({super.key});

  @override
  State<DokumentasiPage> createState() => _DokumentasiPageState();
}

class _DokumentasiPageState extends State<DokumentasiPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _initialized = false;

  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initFirebase() async {
    await Firebase.initializeApp();
    setState(() {
      _initialized = true;
    });
  }

  Future<void> _pickAndUploadImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );

    if (pickedFile == null) return;

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Judul harus diisi")),
      );
      return;
    }

    try {
      final uidUser = UserSession.userId;

      if (uidUser == null || uidUser.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User belum login")),
        );
        return;
      }

      final File file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final String base64Image = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('dokumentasi').add({
        'uidUser': uidUser,
        'judul': _titleController.text,
        'tanggal': Timestamp.now(),
        'fotoBase64': base64Image,
        'deskripsi': _descriptionController.text,
        'createdAt': Timestamp.now(),
      });

      _titleController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dokumentasi berhasil disimpan")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error upload: $e")),
      );
    }
  }

  /// POPUP DETAIL
  void _showDetailPopup(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// GAMBAR BESAR
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: _buildImage(data['fotoBase64']),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      data['judul'] ?? "",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          _formatTanggal(data['tanggal']),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 140,
                      child: SingleChildScrollView(
                        child: Text(
                          data['deskripsi'] ?? "",
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Tutup"),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  /// FORM TAMBAH DATA
  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Text(
                    "Tambah Dokumentasi",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: "Judul",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: "Deskripsi",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Pilih Gambar dari Galeri"),
                    onPressed: () {
                      Navigator.pop(context);
                      _pickAndUploadImage();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return const Icon(Icons.image_not_supported);
    }

    if (!_imageCache.containsKey(base64String)) {
      try {
        _imageCache[base64String] = base64Decode(base64String);
      } catch (e) {
        return const Icon(Icons.broken_image);
      }
    }

    return Image.memory(
      _imageCache[base64String]!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  String _formatTanggal(Timestamp? ts) {
    if (ts == null) return "";

    final d = ts.toDate();

    final tanggal = "${d.day}/${d.month}/${d.year}";
    final waktu =
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

    return "$tanggal • $waktu";
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final uidUser = UserSession.userId;

    if (uidUser == null || uidUser.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("User belum login")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.green,
        centerTitle: true,
        title: const Text(
          "Dokumentasi",
          style: TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontWeight: FontWeight.bold),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dokumentasi')
            .where('uidUser', isEqualTo: uidUser)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text("Belum Ada Dokumentasi"));
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final data = docs[index].data() as Map<String, dynamic>;

              return GestureDetector(
                onTap: () {
                  _showDetailPopup(data);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [

                      Expanded(
                        flex: 6,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(14),
                          ),
                          child: SizedBox(
                            height: 150,
                            child: _buildImage(data['fotoBase64']),
                          ),
                        ),
                      ),

                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Text(
                                data['judul'] ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                data['deskripsi'] ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),

                              const SizedBox(height: 10),

                              Row(
                                children: [

                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey,
                                  ),

                                  const SizedBox(width: 6),

                                  Text(
                                    _formatTanggal(data['tanggal']),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: _showPickOptions,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }
}