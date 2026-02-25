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
    await _firestore.collection('employees').doc(id).delete();
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
