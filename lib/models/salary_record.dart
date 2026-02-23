class WeeklySalary {
  final String employeeId;
  final String employeeName;
  final String weekId;
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
}
