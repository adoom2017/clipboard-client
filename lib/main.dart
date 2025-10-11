import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'models/clipboard_item.dart';
import 'providers/auth_provider.dart';
import 'providers/server_sync_provider.dart';
import 'providers/settings_provider.dart';
import 'services/clipboard_service.dart';
import 'services/api_service.dart';
import 'services/window_service.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'pages/change_password_page.dart';
import 'utils/logger.dart';

// 窗口事件监听器
class MyWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // 关闭窗口时隐藏窗口而不是退出应用
    await windowManager.hide();
    // 防止应用关闭
    await windowManager.setPreventClose(true);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统
  AppLogger.init();

  // 只在桌面平台初始化窗口管理器和热键功能
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // 初始化窗口管理器
    await windowManager.ensureInitialized();

    // 设置窗口属性
    WindowOptions windowOptions = const WindowOptions(
      size: Size(600, 1000),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // 窗口关闭时隐藏而不是退出应用
    windowManager.setPreventClose(true);
    windowManager.addListener(MyWindowListener());

    // 初始化热键管理器
    // 对于热重载，需要先注销所有热键
    await hotKeyManager.unregisterAll();

    // 初始化窗口服务（注册全局热键和系统托盘）
    final windowService = WindowService();
    await windowService.init();
    await windowService.initTrayMenu();
  }

  // 初始化ApiService（加载保存的baseUrl）
  await ApiService().initializeApi();

  // 初始化Hive
  await Hive.initFlutter();

  // 注册Hive适配器
  Hive.registerAdapter(ClipboardItemAdapter());
  Hive.registerAdapter(ClipboardTypeAdapter());

  // 打开Hive盒子
  await Hive.openBox<ClipboardItem>('clipboard_items');

  // 清理过长的剪贴板内容
  await ClipboardService.instance.cleanupLongContent();

  runApp(const ClipboardApp());
}

class ClipboardApp extends StatelessWidget {
  const ClipboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => ServerSyncProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => ClipboardService.instance,
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF007AFF), // iOS蓝色
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'SF Pro Text', // 苹果字体（如果有的话）
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                scrolledUnderElevation: 0,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              cardTheme: CardTheme(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                shadowColor: Colors.black.withOpacity(0.1),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS背景色
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0A84FF), // iOS深色模式蓝色
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              fontFamily: 'SF Pro Text',
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                scrolledUnderElevation: 0,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              cardTheme: CardTheme(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: const Color(0xFF1C1C1E),
                shadowColor: Colors.black.withOpacity(0.3),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
              scaffoldBackgroundColor: const Color(0xFF000000), // iOS深色背景
            ),
            themeMode: ThemeMode.system,

            // 根据认证状态决定显示哪个页面
            home: authProvider.isLoading
                ? const SplashScreen()
                : authProvider.isAuthenticated
                    ? const MainPage()
                    : const LoginPage(),

            // 路由配置
            routes: {
              '/login': (context) => const LoginPage(),
              '/main': (context) => const MainPage(),
              '/change-password': (context) => const ChangePasswordPage(),
            },
          );
        },
      ),
    );
  }
}

// 启动画面
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.content_paste,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 24),
            Text(
              '剪贴板同步工具',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
