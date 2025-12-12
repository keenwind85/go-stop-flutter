import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/debug_config_service.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/lobby_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Debug Config 초기화
  final debugConfigService = DebugConfigService();
  await debugConfigService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        debugConfigServiceProvider.overrideWithValue(debugConfigService),
      ],
      child: const GoStopApp(),
    ),
  );
}

class GoStopApp extends ConsumerWidget {
  const GoStopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: '맞고 Go-Stop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.doHyeonTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const LobbyScreen();
          }
          return const LoginScreen();
        },
        loading: () => const Scaffold(
          backgroundColor: Color(0xFF1A472A),
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFFD700),
            ),
          ),
        ),
        error: (error, stack) => Scaffold(
          backgroundColor: const Color(0xFF1A472A),
          body: Center(
            child: Text(
              '오류: $error',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
