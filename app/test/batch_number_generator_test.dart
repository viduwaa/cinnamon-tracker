import "package:flutter_test/flutter_test.dart";
import "package:cinnamon_trace/core/domain/batch_number_generator.dart";

/// The 10 required cases from flutter-plan.md §3.3.
void main() {
  group("batch number generator (flutter-plan §3.3)", () {
    test("1. canonical example → GM-172-01-2026-FM-A-T", () {
      // 2026-06-21 is Julian day 172 (31+28+31+30+31 = 151, + 21).
      final no = generateBatchNo(
        areaCode: "GM",
        harvestDate: DateTime(2026, 6, 21),
        seq: 1,
        farmerCode: "A",
        type: HarvestType.trees,
      );
      expect(no, "GM-172-01-2026-FM-A-T");
    });

    test("2. seq padding — 3 → -03-, 12 → -12-", () {
      String no(int seq) => generateBatchNo(
            areaCode: "GM",
            harvestDate: DateTime(2026, 6, 21),
            seq: seq,
            farmerCode: "A",
            type: HarvestType.trees,
          );
      expect(no(3), contains("-03-"));
      expect(no(12), contains("-12-"));
    });

    test("3. Julian day boundaries", () {
      String jd(DateTime d) => generateBatchNo(
            areaCode: "GM",
            harvestDate: d,
            seq: 1,
            farmerCode: "A",
            type: HarvestType.trees,
          ).split("-")[1];
      expect(jd(DateTime(2026, 1, 1)), "001");
      expect(jd(DateTime(2026, 12, 31)), "365"); // non-leap
      expect(jd(DateTime(2028, 12, 31)), "366"); // leap
      expect(jd(DateTime(2028, 2, 29)), "060");
    });

    test("4. quills type → trailing -Q", () {
      final no = generateBatchNo(
        areaCode: "GM",
        harvestDate: DateTime(2026, 6, 21),
        seq: 1,
        farmerCode: "A",
        type: HarvestType.quills,
      );
      expect(no, endsWith("-Q"));
    });

    test("5. numeric and 4-char farmer codes accepted", () {
      final numeric = generateBatchNo(
        areaCode: "GM",
        harvestDate: DateTime(2026, 6, 21),
        seq: 1,
        farmerCode: "21",
        type: HarvestType.trees,
      );
      expect(numeric, contains("-FM-21-"));
      final wide = generateBatchNo(
        areaCode: "GM",
        harvestDate: DateTime(2026, 6, 21),
        seq: 1,
        farmerCode: "A1B2",
        type: HarvestType.trees,
      );
      expect(wide, contains("-FM-A1B2-"));
    });

    test("6. lowercase inputs normalize to uppercase", () {
      final no = generateBatchNo(
        areaCode: "gm",
        harvestDate: DateTime(2026, 6, 21),
        seq: 1,
        farmerCode: "a",
        type: HarvestType.trees,
      );
      expect(no, "GM-172-01-2026-FM-A-T");
    });

    test("7. throws on invalid inputs", () {
      expect(
        () => generateBatchNo(
          areaCode: "G",
          harvestDate: DateTime(2026, 6, 21),
          seq: 1,
          farmerCode: "A",
          type: HarvestType.trees,
        ),
        throwsArgumentError,
      );
      expect(
        () => generateBatchNo(
          areaCode: "GMA",
          harvestDate: DateTime(2026, 6, 21),
          seq: 1,
          farmerCode: "A",
          type: HarvestType.trees,
        ),
        throwsArgumentError,
      );
      expect(
        () => generateBatchNo(
          areaCode: "GM",
          harvestDate: DateTime(2026, 6, 21),
          seq: 1,
          farmerCode: "",
          type: HarvestType.trees,
        ),
        throwsArgumentError,
      );
      expect(
        () => generateBatchNo(
          areaCode: "GM",
          harvestDate: DateTime(2026, 6, 21),
          seq: 1,
          farmerCode: "ABCDE",
          type: HarvestType.trees,
        ),
        throwsArgumentError,
      );
      expect(
        () => generateBatchNo(
          areaCode: "GM",
          harvestDate: DateTime(2026, 6, 21),
          seq: 0,
          farmerCode: "A",
          type: HarvestType.trees,
        ),
        throwsStateError,
      );
      expect(
        () => generateBatchNo(
          areaCode: "GM",
          harvestDate: DateTime(2026, 6, 21),
          seq: 100,
          farmerCode: "A",
          type: HarvestType.trees,
        ),
        throwsStateError,
      );
    });

    test("8. time-of-day is ignored", () {
      final morning = generateBatchNo(
        areaCode: "GM",
        harvestDate: DateTime(2026, 6, 21, 0, 1),
        seq: 1,
        farmerCode: "A",
        type: HarvestType.trees,
      );
      final night = generateBatchNo(
        areaCode: "GM",
        harvestDate: DateTime(2026, 6, 21, 23, 59),
        seq: 1,
        farmerCode: "A",
        type: HarvestType.trees,
      );
      expect(morning, night);
    });

    test("9. every generated sample passes the server-side regex", () {
      for (final seq in [1, 9, 10, 99]) {
        for (final type in HarvestType.values) {
          final no = generateBatchNo(
            areaCode: "GM",
            harvestDate: DateTime(2026, 6, 21),
            seq: seq,
            farmerCode: "A7",
            type: type,
          );
          expect(isValidBatchNo(no), isTrue, reason: no);
        }
      }
    });

    test("10. year comes from the harvest date", () {
      final no = generateBatchNo(
        areaCode: "GM",
        harvestDate: DateTime(2027, 1, 1),
        seq: 1,
        farmerCode: "A",
        type: HarvestType.trees,
      );
      expect(no, contains("-2027-"));
    });
  });
}
