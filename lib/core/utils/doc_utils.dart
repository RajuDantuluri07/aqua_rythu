import 'time_provider.dart';

int calculateDocFromStockingDate(DateTime stockingDate, {DateTime? now}) {
  final current = now ?? TimeProvider.now();
  final todayUtc = DateTime.utc(current.year, current.month, current.day);
  final stockingUtc = DateTime.utc(
    stockingDate.year,
    stockingDate.month,
    stockingDate.day,
  );

  final doc = todayUtc.difference(stockingUtc).inDays + 1;
  return doc > 0 ? doc : 1;
}
