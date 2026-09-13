import 'package:flutter/material.dart';
import 'student_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({
    super.key,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return StudentDashboardScreen(userData: userData);
  }
}
