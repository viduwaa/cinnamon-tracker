/**
 * Canonical phone number normalization.
 *
 * Normalizes any local or international representation of a phone number
 * into standard E.164 format (+<country_code><national_digits>).
 *
 * Supports:
 * - Sri Lankan numbers:
 *   - '0771234567'  -> '+94771234567' (leading 0 replaced with +94)
 *   - '771234567'   -> '+94771234567' (9 digits starting with 7)
 *   - '94771234567'  -> '+94771234567' (11 digits starting with 94)
 *   - '0094771234567'-> '+94771234567' (00 trunk replaced with +)
 *   - '+94771234567' -> '+94771234567'
 * - International numbers:
 *   - '+1 (202) 555-0123' -> '+12025550123'
 *   - '+44 7911 123456'   -> '+447911123456'
 *   - '0012025550123'     -> '+12025550123'
 */
export function normalizeMobile(raw: string, defaultCountryCode = "+94"): string {
  if (!raw) return "";

  // 1. Remove all spaces, hyphens, parentheses, dots
  let digits = raw.trim().replace(/[\s\-().]/g, "");
  if (!digits) return "";

  // 2. Convert international trunk prefix 00 to +
  if (digits.startsWith("00")) {
    digits = "+" + digits.substring(2);
  }

  // 3. Already has standard E.164 + prefix
  if (digits.startsWith("+")) {
    return digits;
  }

  // 4. Sri Lanka: starts with 94 (without +) and has 11 digits (e.g. 94771234567)
  if (digits.startsWith("94") && digits.length === 11) {
    return "+" + digits;
  }

  // 5. Local national format starting with 0 (e.g. 0771234567 -> +94771234567)
  if (digits.startsWith("0")) {
    const code = defaultCountryCode.startsWith("+")
      ? defaultCountryCode
      : `+${defaultCountryCode}`;
    return `${code}${digits.substring(1)}`;
  }

  // 6. 9-digit Sri Lankan mobile number starting with 7 (e.g. 771234567)
  if (digits.length === 9 && digits.startsWith("7")) {
    return `+94${digits}`;
  }

  // 7. General fallback: prepend default country code
  const code = defaultCountryCode.startsWith("+")
    ? defaultCountryCode
    : `+${defaultCountryCode}`;
  return `${code}${digits}`;
}
