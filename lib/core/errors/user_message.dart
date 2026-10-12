import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns an exception into one Indonesian sentence a person can act on.
String userMessage(Object error) {
  if (error is AuthException) return _authMessage(error);
  if (error is PostgrestException) return _dbMessage(error);
  if (error is TimeoutException || _looksOffline(error)) {
    return 'Tidak bisa terhubung. Periksa koneksi internet Anda lalu coba lagi.';
  }
  return 'Terjadi kesalahan yang tidak terduga. Coba lagi sebentar lagi.';
}

bool _looksOffline(Object error) {
  final s = error.toString();
  return s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('XMLHttpRequest');
}

String _authMessage(AuthException e) {
  switch (e.code) {
    case 'invalid_credentials':
      return 'Email atau kata sandi salah.';
    case 'email_not_confirmed':
      return 'Email belum dikonfirmasi. Buka tautan yang kami kirim ke email '
          'Anda.';
    case 'user_already_exists':
    case 'email_exists':
      return 'Email ini sudah terdaftar. Silakan masuk.';
    case 'weak_password':
      return 'Kata sandi terlalu lemah. Pakai minimal 8 karakter.';
    case 'same_password':
      return 'Kata sandi baru harus berbeda dari yang lama.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Terlalu banyak permintaan. Tunggu beberapa menit lalu coba lagi.';
    case 'email_address_invalid':
      return 'Alamat email tidak valid.';
    case 'signup_disabled':
      return 'Pendaftaran akun baru sedang ditutup.';
  }
  if (_looksOffline(e)) {
    return 'Tidak bisa terhubung. Periksa koneksi internet Anda lalu coba lagi.';
  }
  return 'Gagal memproses akun: ${e.message}';
}

String _dbMessage(PostgrestException e) {
  switch (e.code) {
    case '42501':
      return 'Anda tidak punya akses ke data ini. Coba keluar lalu masuk lagi.';
    case '23514':
      return 'Isian tidak memenuhi aturan. Periksa kembali lalu simpan.';
    case '23503':
      return 'Data ini masih dipakai di tempat lain, jadi belum bisa dihapus.';
  }
  return 'Gagal menyimpan ke database. Coba lagi sebentar lagi.';
}
