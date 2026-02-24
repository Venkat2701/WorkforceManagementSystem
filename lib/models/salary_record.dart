class WeeklySalary {
  final String employeeId;
  final String employeeName;
  final String weekId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalHours;
  final double totalOvertime;
  final double hourlyRate;
  final double overtimeRate;
  final double baseSalary;
  final double overtimePay;
  final double totalSalary;
  final bool paid;

  WeeklySalary({
    required this.employeeId,
    required this.employeeName,
    required this.weekId,
    required this.startDate,
    required this.endDate,
    required this.totalHours,
    required this.totalOvertime,
    required this.hourlyRate,
    required this.overtimeRate,
    required this.baseSalary,
    required this.overtimePay,
    required this.totalSalary,
    this.paid = false,
  });

  factory WeeklySalary.calculate({
    required String employeeId,
    required String employeeName,
    required String weekId,
    required DateTime startDate,
    required DateTime endDate,
    required double hours,
    required double overtime,
    required double hRate,
    required double oRate,
  }) {
    final base = hours * hRate;
    final ovt = overtime * oRate;
    return WeeklySalary(
      employeeId: employeeId,
      employeeName: employeeName,
      weekId: weekId,
      startDate: startDate,
      endDate: endDate,
      totalHours: hours,
      totalOvertime: overtime,
      hourlyRate: hRate,
      overtimeRate: oRate,
      baseSalary: base,
      overtimePay: ovt,
      totalSalary: base + ovt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'weekId': weekId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalHours': totalHours,
      'totalOvertime': totalOvertime,
      'hourlyRate': hourlyRate,
      'overtimeRate': overtimeRate,
      'baseSalary': baseSalary,
      'overtimePay': overtimePay,
      'totalSalary': totalSalary,
      'paid': paid,
    };
  }

  factory WeeklySalary.fromMap(Map<String, dynamic> map) {
    return WeeklySalary(
      employeeId: map['employeeId'],
      employeeName: map['employeeName'],
      weekId: map['weekId'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      totalHours: (map['totalHours'] as num).toDouble(),
      totalOvertime: (map['totalOvertime'] as num).toDouble(),
      hourlyRate: (map['hourlyRate'] as num).toDouble(),
      overtimeRate: (map['overtimeRate'] as num).toDouble(),
      baseSalary: (map['baseSalary'] as num).toDouble(),
      overtimePay: (map['overtimePay'] as num).toDouble(),
      totalSalary: (map['totalSalary'] as num).toDouble(),
      paid: map['paid'] ?? false,
    );
  }
}
