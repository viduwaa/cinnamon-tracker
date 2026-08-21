/// On-device batch number generator — pure and unit-testable.
///
/// Format: {AREA2}-{JULIANDAY3}-{SEQ2}-{YEAR4}-FM-{FARMERCODE}-{T|Q}
/// Example: GM-172-01-2026-FM-A-T
///
/// AREA2 comes from the farm's district, JULIANDAY is the 1-based day of
/// year of the harvest date, SEQ is a per-farm daily counter, FARMERCODE is
/// assigned by the server when the farm is created.
enum HarvestType { trees, quills }

extension HarvestTypeX on HarvestType {
  String get code => this == HarvestType.trees ? "T" : "Q";
}

/// 1-based day of year.
int julianDay(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final jan1 = DateTime.utc(date.year, 1, 1);
  return d.difference(jan1).inDays + 1;
}

/// Returns e.g. 'GM-172-01-2026-FM-A-T'.
/// Throws [ArgumentError] on invalid inputs, [StateError] if seq > 99.
String generateBatchNo({
  required String areaCode,
  required DateTime harvestDate,
  required int seq,
  required String farmerCode,
  required HarvestType type,
}) {
  final area = areaCode.toUpperCase();
  if (!RegExp(r"^[A-Z]{2}$").hasMatch(area)) {
    throw ArgumentError("areaCode must be 2 letters");
  }
  final fc = farmerCode.toUpperCase();
  if (!RegExp(r"^[A-Z0-9]{1,4}$").hasMatch(fc)) {
    throw ArgumentError("farmerCode must be 1-4 letters/digits");
  }
  if (seq < 1 || seq > 99) {
    throw StateError("seq out of range: $seq");
  }
  final jd = julianDay(harvestDate).toString().padLeft(3, "0");
  final s = seq.toString().padLeft(2, "0");
  return "$area-$jd-$s-${harvestDate.year}-FM-$fc-${type.code}";
}

final batchNoPattern =
    RegExp(r"^[A-Z]{2}-\d{3}-\d{2}-\d{4}-FM-[A-Z0-9]{1,4}-[TQ]$");

bool isValidBatchNo(String s) => batchNoPattern.hasMatch(s);
