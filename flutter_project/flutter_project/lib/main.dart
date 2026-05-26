import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/notification_background_worker.dart';
import 'services/notification_navigation_service.dart';
import 'services/push_notification_service.dart';
import 'utils/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final navigatorKey = GlobalKey<NavigatorState>();
  NotificationNavigationService.bindNavigator(navigatorKey);

  try {
    await PushNotificationService.initialize();
    await NotificationBackgroundWorker.configure();
  } catch (_) {}

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF5C1400),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: true,
  ));

  runApp(AppBootstrap(navigatorKey: navigatorKey));
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..tryAutoLogin(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF5C1400),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: Color(0xFF5C1400),
              systemNavigationBarIconBrightness: Brightness.light,
            ),
          ),
        ),
        home: const _SplashGate(),
      ),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _splashDone = false;
  bool _pendingPayloadConsumed = false;

  void _onSplashComplete() {
    if (mounted) setState(() => _splashDone = true);
  }

  void _consumePendingPayloadOnce() {
    if (_pendingPayloadConsumed) return;
    _pendingPayloadConsumed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await NotificationNavigationService.consumePendingPayload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isInitialized && auth.isAuthenticated) {
      _consumePendingPayloadOnce();
      return const StoreApp();
    }

    if (!_splashDone || !auth.isInitialized) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    return const StoreApp();
  }
}
