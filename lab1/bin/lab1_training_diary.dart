import 'package:lab1_training_diary/training_diary.dart';

void main() {
  final result = processLines(sourceLines);

  print(
    buildReport(
      result.items,
      invalidLines: result.errors,
      sortBy: SortCriterion.distance,
    ),
  );
}
