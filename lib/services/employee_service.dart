import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee.dart';

final employeeServiceProvider = Provider((ref) => EmployeeService());

final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  return ref.watch(employeeServiceProvider).getEmployees();
});

class EmployeeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Employee>> getEmployees() {
    return _firestore.collection('employees').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Employee.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addEmployee(Employee employee) async {
    await _firestore.collection('employees').add(employee.toMap());
  }

  Future<void> updateEmployee(Employee employee) async {
    await _firestore
        .collection('employees')
        .doc(employee.id)
        .update(employee.toMap());
  }

  Future<void> archiveEmployee(String id) async {
    await _firestore.collection('employees').doc(id).update({
      'status': 'Archived',
    });
  }

  Future<void> unarchiveEmployee(String id) async {
    await _firestore.collection('employees').doc(id).update({
      'status': 'Active',
    });
  }

  Future<void> deleteEmployee(String id) async {
    final batch = _firestore.batch();

    // 1. Delete employee document
    batch.delete(_firestore.collection('employees').doc(id));

    // 2. Delete attendance records
    final attendanceSnapshot = await _firestore
        .collection('attendance')
        .where('employeeId', isEqualTo: id)
        .get();
    for (var doc in attendanceSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 3. Delete salary records (if any in weekly_salaries)
    final salarySnapshot = await _firestore
        .collection('weekly_salaries')
        .where('employeeId', isEqualTo: id)
        .get();
    for (var doc in salarySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<bool> isNameDuplicate(String name, {String? excludeId}) async {
    final query = _firestore
        .collection('employees')
        .where('name', isEqualTo: name);
    final snapshot = await query.get();
    if (excludeId == null) return snapshot.docs.isNotEmpty;
    return snapshot.docs.any((doc) => doc.id != excludeId);
  }

  Future<bool> isAadharDuplicate(String aadhar, {String? excludeId}) async {
    final query = _firestore
        .collection('employees')
        .where('aadharNumber', isEqualTo: aadhar);
    final snapshot = await query.get();
    if (excludeId == null) return snapshot.docs.isNotEmpty;
    return snapshot.docs.any((doc) => doc.id != excludeId);
  }
}
