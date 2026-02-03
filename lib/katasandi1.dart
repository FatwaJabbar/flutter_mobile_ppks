import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart'; // session untuk userId

class KataSandi1 extends StatefulWidget {
  const KataSandi1({super.key});

  @override
  State<KataSandi1> createState() => _KataSandi1State();
}

class _KataSandi1State extends State<KataSandi1> {
  final passC = TextEditingController();
  bool saving = false;

  Future<void> _savePassword() async {
    final newPass = passC.text.trim();

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password minimal 6 karakter")),
      );
      return;
    }

    if (UserSession.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User tidak ditemukan")),
      );
      return;
    }

    try {
      setState(() => saving = true);

      // update Firestore password
      await FirebaseFirestore.instance
          .collection('users')
          .doc(UserSession.userId)
          .set({
        'password': newPass,
        'hasPassword': true,
      }, SetOptions(merge: true));

      // update session
      UserSession.hasPassword = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password berhasil diperbarui")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan: $e")),
      );
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kata Sandi"), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: passC,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password Baru"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : _savePassword,
              child: Text(saving ? "Menyimpan..." : "Simpan"),
            )
          ],
        ),
      ),
    );
  }
}
