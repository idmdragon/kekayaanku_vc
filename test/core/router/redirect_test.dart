import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/core/router/app_router.dart';

String? r(
  String location, {
  bool configured = true,
  bool signedIn = false,
  bool recovering = false,
}) => authRedirect(
  configured: configured,
  signedIn: signedIn,
  recovering: recovering,
  location: location,
);

void main() {
  test('unconfigured builds only show the setup screen', () {
    expect(r('/beranda', configured: false), '/setup');
    expect(r('/setup', configured: false), isNull);
  });

  test('signed-out users stay on the auth screens', () {
    expect(r('/beranda'), '/masuk');
    expect(r('/kantong/abc'), '/masuk');
    expect(r('/masuk'), isNull);
    expect(r('/daftar'), isNull);
    expect(r('/lupa-sandi'), isNull);
  });

  test('signed-in users skip the auth screens', () {
    expect(r('/masuk', signedIn: true), '/beranda');
    expect(r('/', signedIn: true), '/beranda');
    expect(r('/kantong', signedIn: true), isNull);
    expect(r('/setup', signedIn: true), '/');
  });

  test('a password-recovery session must set a new password first', () {
    expect(r('/beranda', signedIn: true, recovering: true), '/sandi-baru');
    expect(r('/sandi-baru', signedIn: true, recovering: true), isNull);
  });
}
