import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift.dart';

final shiftServiceProvider = Provider((ref) => ShiftService());

final shiftsStreamProvider = StreamProvider<List<Shift>>((ref) {
  return ref.watch(shiftServiceProvider).getShifts();
});

class ShiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Shift>> getShifts() {
    return _firestore.collection('shifts').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Shift.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addShift(Shift shift) async {
    await _firestore.collection('shifts').add(shift.toMap());
  }

  Future<void> updateShift(Shift shift) async {
    await _firestore.collection('shifts').doc(shift.id).update(shift.toMap());
  }

  Future<void> deleteShift(String id) async {
    await _firestore.collection('shifts').doc(id).delete();
  }
}
