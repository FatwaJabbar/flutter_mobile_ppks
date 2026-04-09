class UserSession {
  static String? userId;
  static String? nama;
  static String? role; // <--- INI YANG PENTING, HARUS ADA
  static String? bio;
  static String? telp;
  static String? fotoBase64;
  static String? fotoGoogleUrl;
  static bool hasPassword = false;
  static bool isGoogleUser = false;

  static void clear() {
    userId = null;
    nama = null;
    role = null; // Reset role saat logout
    bio = null;
    telp = null;
    fotoBase64 = null;
    fotoGoogleUrl = null;
    hasPassword = false;
    isGoogleUser = false;
  }
}