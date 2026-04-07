/// Daily feed distribution across 4 rounds.
const Map<int, double> roundDistribution = {
  1: 0.25,
  2: 0.25,
  3: 0.25,
  4: 0.25,
};

/// Default feeding times for each round.
const Map<int, String> roundTimings = {
  1: "06:00",
  2: "11:00",
  3: "16:00",
  4: "21:00",
};

/// Returns the feed type recommended for the given Day of Culture (DOC).
///
/// This logic applies primarily for the first 30 days.
String getFeedType(int doc) {
  if (doc <= 7) {
    return "1R";
  } else if (doc <= 14) {
    return "1R + 2R";
  } else if (doc <= 21) {
    return "2R";
  } else if (doc <= 28) {
    return "2R + 3S";
  }
  return "3S";
}
