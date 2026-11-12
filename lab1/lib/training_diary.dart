typedef Training = ({
  DateTime date,
  String activity,
  int durationMinutes,
  double distanceKilometers,
  int heartRate,
  String wellbeing,
});
typedef ProcessingResult = ({List<Training> items, List<String> errors});

enum SortCriterion { duration, distance }

const sourceLines = <String>[
  '2026-10-02;біг ранок;42;7.2;148;добре',
  '2026-10-03;йога;50;0;92;відмінно',
  '2026-10-05;плавання;35;1.1;132;добре',
  '2026-10-06;велосипед;65;18.4;142;добре',
  '2026-10-08;біг інтервали;38;6.0;164;втома',
  '2026-10-10;силове;55;0;126;добре',
  '2026-10-12;ходьба;75;5.8;105;добре',
  '2026-10-14;біг вечір;31;5.0;151;нормально',
  '2026-10-16;плавання;40;1.3;136;добре',
  '2026-10-18;велосипед;90;27.5;145;відмінно',
  '2026-10-20;йога;45;0;88;добре',
  '2026-10-22;біг темповий;47;8.1;158;втома',
  '2026-10-24;ходьба;60;4.7;101;добре',
  '2026-10-26;силове;58;0;130;нормально',
  '2026-10-28;біг легкий;36;5.5;144;добре',
  '2026-10-29;плавання;не число;1.0;128;добре',
  '2026-10-30;велосипед;50;12.0;140',
  '2026-13-01;йога;40;0;90;добре',
];

final _activityPattern = RegExp(
  r'^(?<kind>[А-Яа-яІіЇїЄєA-Za-z]+)(?:\s+(?<detail>[А-Яа-яІіЇїЄєA-Za-z]+))?$',
);

({Training? item, String? error}) parseTraining(String line) {
  final fields = line.split(';');
  if (fields.length != 6) {
    return (item: null, error: 'очікується 6 полів, отримано ${fields.length}');
  }

  final date = DateTime.tryParse(fields[0]);
  final duration = int.tryParse(fields[2]);
  final distance = double.tryParse(fields[3]);
  final heartRate = int.tryParse(fields[4]);

  if (date == null || date.toIso8601String().substring(0, 10) != fields[0]) {
    return (item: null, error: 'некоректна дата "${fields[0]}"');
  }
  if (duration == null || distance == null || heartRate == null) {
    return (item: null, error: 'некоректне числове поле');
  }
  if (!_activityPattern.hasMatch(fields[1])) {
    return (item: null, error: 'некоректний формат виду активності');
  }

  final item = (
    date: date,
    activity: fields[1],
    durationMinutes: duration,
    distanceKilometers: distance,
    heartRate: heartRate,
    wellbeing: fields[5],
  );
  final violations = validateTraining(item);
  if (violations.isNotEmpty) {
    return (item: null, error: violations.join(', '));
  }
  return (item: item, error: null);
}

List<String> validateTraining(Training item) {
  final violations = <String>[];
  if (item.date.year < 2020 || item.date.year > 2030) {
    violations.add('рік має бути в межах 2020–2030');
  }
  if (item.durationMinutes <= 0 || item.durationMinutes > 600) {
    violations.add('тривалість має бути від 1 до 600 хвилин');
  }
  if (item.distanceKilometers < 0 || item.distanceKilometers > 300) {
    violations.add('дистанція має бути від 0 до 300 км');
  }
  if (item.heartRate < 40 || item.heartRate > 230) {
    violations.add('пульс має бути від 40 до 230');
  }
  if (item.wellbeing.trim().isEmpty) {
    violations.add('самопочуття не може бути порожнім');
  }
  return violations;
}

ProcessingResult processLines(List<String> lines) {
  var processedCount = 0;
  int countProcessed() => ++processedCount;

  final parsed = lines.map((line) {
    countProcessed();
    return (line: line, result: parseTraining(line));
  }).toList();

  final items = parsed
      .where((entry) => entry.result.item != null)
      .map((entry) => entry.result.item!)
      .toList();
  final errors = parsed
      .where((entry) => entry.result.error != null)
      .map((entry) => '"${entry.line}": ${entry.result.error}')
      .toList();

  if (processedCount != lines.length) {
    throw StateError('Оброблено не всі рядки.');
  }
  return (items: items, errors: errors);
}

Map<String, List<Training>> groupByActivityKind(Iterable<Training> items) {
  return items.fold(<String, List<Training>>{}, (groups, item) {
    final kind = _activityPattern
        .firstMatch(item.activity)!
        .namedGroup('kind')!;
    groups.putIfAbsent(kind, () => <Training>[]).add(item);
    return groups;
  });
}

String maskActivityDetail(String activity) {
  return activity.replaceAllMapped(_activityPattern, (match) {
    final activityMatch = match as RegExpMatch;
    final kind = activityMatch.namedGroup('kind')!;
    final detail = activityMatch.namedGroup('detail');
    return detail == null ? kind : '$kind ${'*' * detail.length}';
  });
}

String buildReport(
  List<Training> items, {
  List<String> invalidLines = const [],
  SortCriterion sortBy = SortCriterion.duration,
  bool ascending = false,
  String separator = ' | ',
  DateTime? reportDate,
}) {
  final referenceDate = reportDate ?? DateTime(2026, 11, 1);
  final sortedItems = [...items]
    ..sort((left, right) {
      final comparison = switch (sortBy) {
        SortCriterion.duration => left.durationMinutes.compareTo(
          right.durationMinutes,
        ),
        SortCriterion.distance => left.distanceKilometers.compareTo(
          right.distanceKilometers,
        ),
      };
      return ascending ? comparison : -comparison;
    });

  final totalMinutes = items
      .map((item) => item.durationMinutes)
      .fold(0, (sum, value) => sum + value);
  final totalDistance = items
      .map((item) => item.distanceKilometers)
      .fold(0.0, (sum, value) => sum + value);
  final highPulseCount = items.where((item) => item.heartRate >= 150).length;
  final averageHeartRate =
      items.map((item) => item.heartRate).fold(0, (sum, value) => sum + value) /
      items.length;
  final groups = groupByActivityKind(items);
  final buffer = StringBuffer()
    ..writeln('ЩОДЕННИК ТРЕНУВАНЬ')
    ..writeln(
      'Коректних записів: ${items.length}; відхилених: ${invalidLines.length}',
    )
    ..writeln('Загальна тривалість: $totalMinutes хв')
    ..writeln('Загальна дистанція: ${totalDistance.toStringAsFixed(1)} км')
    ..writeln('Середній пульс: ${averageHeartRate.toStringAsFixed(1)} уд/хв')
    ..writeln('Тренувань з пульсом від 150: $highPulseCount')
    ..writeln('\nГрупування за видом активності:');

  for (final entry in groups.entries) {
    final averageDuration =
        entry.value
            .map((item) => item.durationMinutes)
            .fold(0, (sum, value) => sum + value) /
        entry.value.length;
    buffer.writeln(
      '${entry.key}: ${entry.value.length} запис(ів), '
      'середня тривалість ${averageDuration.toStringAsFixed(1)} хв',
    );
  }

  buffer.writeln(
    '\nЗаписи (${sortBy.name}, ${ascending ? 'за зростанням' : 'за спаданням'}):',
  );
  for (final item in sortedItems) {
    final ageInDays = referenceDate.difference(item.date).inDays;
    buffer.writeln(
      [
        item.date.toIso8601String().substring(0, 10),
        maskActivityDetail(item.activity),
        '${item.durationMinutes} хв',
        '${item.distanceKilometers.toStringAsFixed(1)} км',
        '${item.heartRate} уд/хв',
        'давність $ageInDays дн.',
      ].join(separator),
    );
  }

  if (invalidLines.isNotEmpty) {
    buffer.writeln('\nВідхилені записи:');
    invalidLines.forEach(buffer.writeln);
  }
  return buffer.toString();
}
