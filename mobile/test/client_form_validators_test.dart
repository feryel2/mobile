import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_client/utils/client_form_validators.dart';

void main() {
  test('validates client names at the supported length boundaries', () {
    expect(validateClientFullName(' AB '), isNull);
    expect(validateClientFullName(''), isNotNull);
    expect(validateClientFullName(List.filled(81, 'A').join()), isNotNull);
  });

  test('accepts standard and plus-addressed email addresses only', () {
    expect(validateClientEmail(' alex@example.com '), isNull);
    expect(validateClientEmail('alex+rentals@example.com'), isNull);
    expect(validateClientEmail('alex@'), isNotNull);
  });

  test('validates phone digits and rejects non-phone characters', () {
    expect(validateClientPhone('+33 (6) 12-34-56-78'), isNull);
    expect(validateClientPhone('123456'), isNotNull);
    expect(validateClientPhone('1234567abc'), isNotNull);
    expect(validateClientPhone(List.filled(16, '1').join()), isNotNull);
  });

  test('requires a six-character password and bounds the optional license', () {
    expect(validateClientPassword('123456'), isNull);
    expect(validateClientPassword('12345'), isNotNull);
    expect(validateDriverLicenseNumber(''), isNull);
    expect(
        validateDriverLicenseNumber(List.filled(101, 'L').join()), isNotNull);
  });
}
