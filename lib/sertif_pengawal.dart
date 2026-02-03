import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class SertifPengawalPage extends StatefulWidget {
  const SertifPengawalPage({super.key});

  @override
  State<SertifPengawalPage> createState() => _SertifPengawalPageState();
}

class _SertifPengawalPageState extends State<SertifPengawalPage> {
  PlatformFile? selectedFile;

  Future<void> pickSertifikat() async {
    final result = await FilePicker.platform.pickFiles();

    if (!mounted) return;

    if (result != null) {
      setState(() {
        selectedFile = result.files.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sertifikat Pengawal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: pickSertifikat,
              child: const Text('Upload Sertifikat'),
            ),
            if (selectedFile != null)
              Text('File: ${selectedFile!.name}')
          ],
        ),
      ),
    );
  }
}
