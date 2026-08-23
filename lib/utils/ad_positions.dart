import 'dart:math';

/// Content items ke beech ad positions randomly generate karta hai.
/// Pattern: pehla ad 3-5 items ke baad, phir har ad 3-8 items ka gap.
/// Zaroori nahi ke exactly 3 ke baad aaye — randomness se user
/// disturbed nahi hota aur ads bhi natural lagte hain.
List<int> randomAdPositions(int totalItems, {int minGap = 3, int maxGap = 8, int? seed}) {
  if (totalItems < minGap) return const [];
  final rng = seed != null ? Random(seed) : Random();
  final positions = <int>[];
  var next = minGap + rng.nextInt(maxGap - minGap + 1);
  while (next < totalItems) {
    positions.add(next);
    next += minGap + rng.nextInt(maxGap - minGap + 1);
  }
  return positions;
}
