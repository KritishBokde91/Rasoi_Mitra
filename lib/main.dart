import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sizer/sizer.dart';
import 'dashboard/presentation/pages/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(RasoiMitraApp());
}

class RasoiMitraApp extends StatelessWidget {
  const RasoiMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'RasoiMitra',
          theme: ThemeData(
            primarySwatch: Colors.deepOrange,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            fontFamily: 'Roboto',
            primaryColor: const Color(0xFFFF6B35),
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Color(0xFF2D3748)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          home: SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      }
    );
  }
}