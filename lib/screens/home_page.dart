import 'package:flutter/material.dart';
import '../widgets/custom_toast.dart';

class AcadovaHomePage extends StatefulWidget {
  const AcadovaHomePage({super.key, required this.title});

  final String title;

  @override
  State<AcadovaHomePage> createState() => _AcadovaHomePageState();
}

class _AcadovaHomePageState extends State<AcadovaHomePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.school),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Logo display card
              Card(
                elevation: 4,
                shape: const CircleBorder(),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.school, size: 80, color: Color(0xFF6C5CE7)),
                          SizedBox(height: 8),
                          Text('Acadova Logo'),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome to Acadova',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your Academic workspace',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () {
                  CustomToast.show(
                    context,
                    title: 'Acadova Quiz',
                    message: 'Starting Acadova Quiz session...',
                    type: ToastType.success,
                    customIcon: Icons.play_circle_fill_rounded,
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
