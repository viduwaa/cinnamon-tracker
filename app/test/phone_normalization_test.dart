import "package:cinnamon_trace/core/widgets/phone_input_field.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("normalizePhoneNumber", () {
    test("normalizes local 10-digit Sri Lanka number with 0", () {
      expect(normalizePhoneNumber("0771234567"), "+94771234567");
      expect(normalizePhoneNumber("071 234 5678"), "+94712345678");
      expect(normalizePhoneNumber("077-123-4567"), "+94771234567");
      expect(normalizePhoneNumber("(077) 1234567"), "+94771234567");
    });

    test("normalizes 9-digit Sri Lanka number without 0", () {
      expect(normalizePhoneNumber("771234567"), "+94771234567");
    });

    test("normalizes Sri Lanka number with 94 missing +", () {
      expect(normalizePhoneNumber("94771234567"), "+94771234567");
    });

    test("preserves existing +94 numbers", () {
      expect(normalizePhoneNumber("+94771234567"), "+94771234567");
      expect(normalizePhoneNumber("+94 77 123 4567"), "+94771234567");
    });

    test("normalizes international numbers with 00 prefix", () {
      expect(normalizePhoneNumber("0094771234567"), "+94771234567");
      expect(normalizePhoneNumber("0012025550123"), "+12025550123");
    });

    test("normalizes international country codes when selected", () {
      expect(normalizePhoneNumber("2025550123", defaultDialCode: "+1"), "+12025550123");
      expect(normalizePhoneNumber("07911123456", defaultDialCode: "+44"), "+447911123456");
      expect(normalizePhoneNumber("9876543210", defaultDialCode: "+91"), "+919876543210");
      expect(normalizePhoneNumber("0412345678", defaultDialCode: "+61"), "+61412345678");
    });

    test("handles empty string gracefully", () {
      expect(normalizePhoneNumber(""), "");
      expect(normalizePhoneNumber("   "), "");
    });
  });
}
