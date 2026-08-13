// file: absensi_face_camera.dart
//
// Halaman ini membuka kamera depan lalu memverifikasi lewat ML Kit Face
// Detection sebelum foto absen disimpan:
//  - Harus terdeteksi tepat 1 wajah (bukan 0, bukan lebih dari 1)
//  - Mata harus terbuka (indikasi wajah asli langsung di depan kamera)
//  - Wajah harus cukup besar / dekat ke kamera
//  - Hasil foto akhir di-flip horizontal (khusus kamera depan) supaya
//    tidak mirror -- sama seperti wajah yang dilihat orang lain, bukan
//    seperti bayangan cermin.
//
// CATATAN JUJUR: ini adalah pengecekan dasar (deteksi wajah + mata terbuka),
// BUKAN liveness detection penuh. Untuk mencegah orang memotret foto/layar
// HP orang lain 100%, idealnya ditambah gerakan acak (challenge-response,
// misal "kedipkan mata" / "hadap kiri") memakai face.headEulerAngleY dan
// face.leftEyeOpenProbability yang berubah antar-frame. Kerangka di bawah
// sudah menyediakan objek `face` sehingga tinggal menambah pengecekan lain
// jika ke depannya mau ditingkatkan.

import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class AbsensiFaceCameraPage extends StatefulWidget {
  const AbsensiFaceCameraPage({super.key});

  @override
  State<AbsensiFaceCameraPage> createState() => _AbsensiFaceCameraPageState();
}

class _AbsensiFaceCameraPageState extends State<AbsensiFaceCameraPage> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _memproses = false;
  String? _pesan;

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
      minFaceSize: 0.25,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initKamera();
  }

  Future<void> _initKamera() async {
    final kameraList = await availableCameras();
    final kameraDepan = kameraList.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => kameraList.first,
    );
    _controller = CameraController(
      kameraDepan,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _ambilFoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _memproses) {
      return;
    }

    setState(() {
      _memproses = true;
      _pesan = "Memeriksa wajah...";
    });

    try {
      final XFile file = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() => _pesan = "Wajah tidak terdeteksi. Pastikan wajah terlihat jelas.");
        return;
      }
      if (faces.length > 1) {
        setState(() => _pesan = "Terdeteksi lebih dari 1 wajah. Pastikan hanya wajah Anda di kamera.");
        return;
      }

      final face = faces.first;
      final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
      final ukuranWajah = face.boundingBox.width;
      final tinggiPreview = _controller!.value.previewSize?.height ?? 480;

      if (leftEyeOpen < 0.35 || rightEyeOpen < 0.35) {
        setState(() => _pesan = "Mata terdeteksi tertutup. Coba lagi dengan mata terbuka.");
        return;
      }

      if (ukuranWajah < tinggiPreview * 0.18) {
        setState(() => _pesan = "Wajah terlalu jauh. Dekatkan wajah Anda ke kamera.");
        return;
      }

      setState(() => _pesan = "Memproses foto...");

      final rawBytes = await File(file.path).readAsBytes();
      final bytes = await _koreksiMirror(rawBytes);

      if (!mounted) return;
      Navigator.pop(context, bytes);
    } catch (e) {
      setState(() => _pesan = "Gagal mengambil foto, coba lagi.");
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  /// Kamera depan biasanya menyimpan hasil foto dalam kondisi ter-mirror
  /// (kebalikan dari apa yang orang lain lihat langsung saat menghadap
  /// kita). Fungsi ini membalik horizontal foto supaya hasil akhirnya
  /// "natural" -- sama seperti wajah asli, bukan seperti bayangan cermin.
  /// Dijalankan lewat `compute` (isolate terpisah) supaya proses decode/
  /// encode gambar tidak nge-freeze UI.
  Future<Uint8List> _koreksiMirror(Uint8List rawBytes) async {
    final lensDepan = _controller?.description.lensDirection == CameraLensDirection.front;
    if (!lensDepan) return rawBytes;
    return compute(_flipHorizontalIsolate, rawBytes);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Verifikasi Wajah", style: TextStyle(color: Colors.white)),
      ),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Preview kamera dikunci di tengah pakai FittedBox + AspectRatio
                    // supaya proporsional dan center di semua ukuran layar/device,
                    // tanpa perlu pengaturan rotasi manual.
                    Center(
                      child: AspectRatio(
                        aspectRatio: 1 / _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),

                    // Panduan oval posisi wajah
                    Center(
                      child: Container(
                        width: 240,
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(150),
                        ),
                      ),
                    ),

                    if (_pesan != null)
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _pesan!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _memproses
                            ? const CircularProgressIndicator(color: Colors.white)
                            : GestureDetector(
                                onTap: _ambilFoto,
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: Colors.green, width: 4),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

/// Top-level function (dibutuhkan oleh `compute` karena harus bisa
/// dijalankan di isolate terpisah). Membalik gambar secara horizontal.
Uint8List _flipHorizontalIsolate(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return rawBytes;
  final flipped = img.flipHorizontal(decoded);
  return Uint8List.fromList(img.encodeJpg(flipped, quality: 90));
}