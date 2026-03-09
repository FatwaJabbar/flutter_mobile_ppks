import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/panen_model.dart'; // SESUAIKAN PATH

class FirebasePanenService {
  final CollectionReference panenCollection =
      FirebaseFirestore.instance.collection('panen');

  /// Simpan data panen ke Firebase
  Future<void> simpanPanen({
    required String userId,
    required Panen panen,
  }) async {
    await panenCollection.add({
      'userId': userId,
      ...panen.toMap(),
      'createdAt': DateTime.now(),
    });
  }

  /// Ambil riwayat panen per user
  Future<List<Panen>> getPanenByUser(String userId) async {
    final query = await panenCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return query.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Panen.fromMap(data);
    }).toList();
  }
}
