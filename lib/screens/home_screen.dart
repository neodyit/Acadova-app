import 'package:flutter/material.dart';
import 'faculty_dashboard_screen.dart';
import 'student_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final role = (userData['role'] ?? '').toString().toLowerCase();
    if (role == 'faculty') {
      return FacultyDashboardScreen(userData: userData);
    }
    return StudentDashboardScreen(userData: userData);
  }
}
