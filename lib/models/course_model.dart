enum WeekCycle { all, odd, even }

class Course {
  final String id;
  final String name;
  final String teacher;
  final int dayOfWeek; // 1-7 周一到周日
  final int startPeriod; // 起始节次 1-13
  final int endPeriod; // 结束节次
  final String location;
  final int colorIndex;
  final WeekCycle weekCycle;
  final String note; // 备注

  static const List<String> dayNames = [
    '一', '二', '三', '四', '五', '六', '日'
  ];

  static const List<String> periodLabels = [
    '08:00', '08:55', '10:00', '10:55', '11:50',
    '14:00', '14:55', '16:00', '16:55', '17:50',
    '19:00', '19:55', '20:50',
  ];

  static const List<int> colors = [
    0xFF5B9BF5, // 蓝
    0xFFFF7B7B, // 珊瑚红
    0xFF4CD964, // 绿
    0xFFFF9500, // 橙
    0xFFAF52DE, // 紫
    0xFFFFCC00, // 金
    0xFF34C759, // 薄荷
    0xFFFF6482, // 桃红
    0xFF00C7BE, // 青
    0xFFA2845E, // 棕色
  ];

  Course({
    required this.id,
    required this.name,
    this.teacher = '',
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
    this.location = '',
    this.colorIndex = 0,
    this.weekCycle = WeekCycle.all,
    this.note = '',
  });

  String get dayLabel => '周${dayNames[dayOfWeek - 1]}';
  int get duration => endPeriod - startPeriod + 1;
  String get timeSlot => '${periodLabels[startPeriod - 1]}-${periodLabels[endPeriod - 1]}';
  String get weekCycleLabel => weekCycle == WeekCycle.all ? '' : (weekCycle == WeekCycle.odd ? '【单】' : '【双】');
  String get fullName => '$name${weekCycleLabel.isNotEmpty ? ' $weekCycleLabel' : ''}';

  bool shouldShowInWeek(int week) {
    if (weekCycle == WeekCycle.all) return true;
    if (weekCycle == WeekCycle.odd) return week % 2 == 1;
    return week % 2 == 0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'teacher': teacher,
        'dayOfWeek': dayOfWeek,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
        'location': location,
        'colorIndex': colorIndex,
        'weekCycle': weekCycle.index,
        'note': note,
      };

  factory Course.fromMap(Map<String, dynamic> m) => Course(
        id: m['id'],
        name: m['name'],
        teacher: m['teacher'] ?? '',
        dayOfWeek: m['dayOfWeek'],
        startPeriod: m['startPeriod'],
        endPeriod: m['endPeriod'],
        location: m['location'] ?? '',
        colorIndex: m['colorIndex'] ?? 0,
        weekCycle: WeekCycle.values[m['weekCycle'] ?? 0],
        note: m['note'] ?? '',
      );
}
