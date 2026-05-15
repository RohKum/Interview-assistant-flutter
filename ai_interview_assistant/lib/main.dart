import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InterviewAssistantApp());
}

class InterviewAssistantApp extends StatelessWidget {
  const InterviewAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Interview Assistant',
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          surface: Colors.black.withOpacity(0.4),
        ),
        useMaterial3: true,
      ),
      home: const AssistantHome(),
    );
  }
}
