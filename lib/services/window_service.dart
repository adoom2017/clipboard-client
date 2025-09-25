import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import '../utils/logger.dart';
import '../utils/tray_icon_generator.dart';

class WindowService with TrayListener {
  static final WindowService _instance = WindowService._internal();
  static final _logger = getLogger('WindowService');

  factory WindowService() {
    return _instance;
  }

  WindowService._internal();

  bool _isVisible = true;
  HotKey? _toggleHotKey;

  // 初始化窗口服务
  Future<void> init() async {
    // 只在桌面平台初始化窗口管理功能
    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        // 注册热键 (Ctrl+Alt+C)
        _toggleHotKey = HotKey(
          key: LogicalKeyboardKey.keyC,
          modifiers: [HotKeyModifier.alt, HotKeyModifier.control],
          scope: HotKeyScope.system, // 系统级热键
        );

        await hotKeyManager.register(
          _toggleHotKey!,
          keyDownHandler: _handleHotKey,
        );

        _logger.info('已注册全局热键: Ctrl+Alt+C');

        // 初始化系统托盘
        await _initTray();
      } catch (e) {
        _logger.severe('初始化窗口服务失败', e);
      }
    } else {
      _logger.info('移动平台不支持窗口管理和系统托盘功能');
    }
  }

  // 初始化系统托盘
  Future<void> _initTray() async {
    try {
      // 添加托盘监听器（只添加一次）
      trayManager.addListener(this);

      _logger.info('正在设置系统托盘图标...');

      // 优先尝试从Flutter资源中提取图标（使用pubspec.yaml中配置的资源）
      try {
        _logger.info('优先尝试从Flutter assets资源中提取图标...');
        await useAssetIcon();
        _logger.info('成功使用Flutter assets资源设置托盘图标！');
      } catch (e) {
        _logger.warning('从Flutter assets设置托盘图标失败: ${e.toString()}');
        _logger.info('回退到其他方法...');
      }

      // 设置托盘工具提示
      await trayManager.setToolTip('剪贴板同步助手');

      _logger.info('系统托盘已初始化');
    } catch (e) {
      _logger.severe('初始化系统托盘失败', e);
      _logger.info('应用将在没有系统托盘图标的情况下继续运行');
    }
  }

  // 处理热键按下事件
  void _handleHotKey(HotKey hotKey) {
    _toggleWindowVisibility();
  }

  // 切换窗口可见性
  Future<void> _toggleWindowVisibility() async {
    // 只在桌面平台执行窗口操作
    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        if (_isVisible) {
          // 如果窗口当前可见，则隐藏
          await windowManager.hide();
          _logger.info('窗口已隐藏');
        } else {
          // 如果窗口当前隐藏，则显示
          await windowManager.show();
          await windowManager.focus();
          _logger.info('窗口已显示');
        }
        _isVisible = !_isVisible;
      } catch (e) {
        _logger.severe('切换窗口可见性失败', e);
      }
    } else {
      _logger.info('移动平台不支持窗口可见性切换');
    }
  }

  // 手动切换窗口可见性（从UI调用）
  Future<void> toggleVisibility() async {
    await _toggleWindowVisibility();
  }

  // 获取当前窗口可见状态
  bool get isVisible => _isVisible;

  // 清理资源
  Future<void> dispose() async {
    // 只在桌面平台清理桌面相关资源
    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        if (_toggleHotKey != null) {
          await hotKeyManager.unregister(_toggleHotKey!);
        }

        // 移除托盘监听器
        trayManager.removeListener(this);

        // 销毁托盘图标
        await trayManager.destroy();
      } catch (e) {
        _logger.severe('清理资源失败', e);
      }
    }
  }

  // 托盘点击事件处理
  @override
  Future<void> onTrayIconMouseDown() async {
    await toggleVisibility();
  }

  // 托盘右键菜单事件处理
  @override
  Future<void> onTrayIconRightMouseDown() async {
    // 只在桌面平台处理托盘事件
    if (!Platform.isAndroid && !Platform.isIOS) {
      await trayManager.popUpContextMenu();
    }
  }

  // 初始化托盘菜单
  Future<void> initTrayMenu() async {
    // 只在桌面平台初始化托盘菜单
    if (!Platform.isAndroid && !Platform.isIOS) {
      try {
        _logger.info('正在初始化托盘菜单...');

        Menu menu = Menu(
          items: [
            MenuItem(
              key: 'toggle_window',
              label: '显示/隐藏窗口 (Ctrl+Alt+C)',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'exit_app',
              label: '退出应用',
            ),
          ],
        );

        await trayManager.setContextMenu(menu);
        _logger.info('托盘菜单初始化完成');
      } catch (e) {
        _logger.severe('初始化托盘菜单失败', e);
      }
    } else {
      _logger.info('移动平台不支持系统托盘菜单');
    }
  } // 处理菜单项点击

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    // 只在桌面平台处理托盘菜单点击
    if (!Platform.isAndroid && !Platform.isIOS) {
      switch (menuItem.key) {
        case 'toggle_window':
          await toggleVisibility();
          break;
        case 'exit_app':
          await windowManager.destroy();
          break;
      }
    }
  }
}
