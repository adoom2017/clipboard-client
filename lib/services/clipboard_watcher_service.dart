import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:flutter/services.dart';
import 'clipboard_service.dart';
import '../utils/logger.dart';

class ClipboardWatcherService with ClipboardListener {
  static final _logger = getLogger('ClipboardWatcher');
  static ClipboardWatcherService? _instance;
  static ClipboardWatcherService get instance {
    _instance ??= ClipboardWatcherService._internal();
    return _instance!;
  }

  ClipboardWatcherService._internal();

  final ClipboardService _clipboardService = ClipboardService.instance;
  bool _isWatching = false;
  String? _lastClipboardContent;

  /// 是否正在监听剪贴板
  bool get isWatching => _isWatching;

  /// 开始监听剪贴板变化
  Future<void> startWatching() async {
    if (_isWatching) return;

    try {
      // 初始化时获取当前剪贴板内容
      await _initializeCurrentClipboard();

      // 注册监听器
      clipboardWatcher.addListener(this);

      // 开始监听
      await clipboardWatcher.start();

      _isWatching = true;
      _logger.info('剪贴板监听已启动');
    } catch (e) {
      _logger.severe('启动剪贴板监听失败', e);

      // 清理可能的残留状态
      try {
        clipboardWatcher.removeListener(this);
      } catch (cleanupError) {
        _logger.warning('清理监听器失败: $cleanupError');
      }

      // 不重新抛出异常，让应用继续运行
      // 可以在UI中显示警告，但不阻塞应用启动
      _logger.warning('剪贴板监听启动失败，将在后台继续尝试');

      // 延迟重试启动监听
      Future.delayed(const Duration(seconds: 2), () async {
        if (!_isWatching) {
          _logger.info('正在重试启动剪贴板监听...');
          try {
            await startWatching();
          } catch (retryError) {
            _logger.warning('重试启动剪贴板监听失败: $retryError');
          }
        }
      });
    }
  }

  /// 停止监听剪贴板变化
  Future<void> stopWatching() async {
    if (!_isWatching) return;

    try {
      // 移除监听器
      clipboardWatcher.removeListener(this);

      // 停止监听
      await clipboardWatcher.stop();

      _isWatching = false;
      _logger.info('剪贴板监听已停止');
    } catch (e) {
      _logger.severe('停止剪贴板监听失败', e);
    }
  }

  /// 初始化当前剪贴板内容
  Future<void> _initializeCurrentClipboard() async {
    try {
      // 添加短暂延迟，等待系统初始化完成
      await Future.delayed(const Duration(milliseconds: 500));

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _lastClipboardContent = data?.text;
      _logger
          .info('初始化剪贴板内容: ${_lastClipboardContent?.substring(0, 50) ?? "空"}');
    } catch (e) {
      _logger.warning('获取初始剪贴板内容失败: $e');
      // 初始化失败不影响后续监听
      _lastClipboardContent = null;
    }
  }

  @override
  void onClipboardChanged() async {
    try {
      // 添加重试机制处理Windows剪贴板访问问题
      String? newContent;
      const maxRetries = 3;
      const retryDelay = Duration(milliseconds: 100);

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          newContent = data?.text;
          break; // 成功获取，跳出重试循环
        } catch (e) {
          if (attempt == maxRetries - 1) {
            // 最后一次尝试失败，记录错误但不抛出异常
            _logger.warning('获取剪贴板内容失败(尝试${attempt + 1}次): $e');
            return;
          }
          // 短暂延迟后重试
          await Future.delayed(retryDelay);
          _logger.warning('剪贴板访问失败，正在重试(${attempt + 1}/$maxRetries): $e');
        }
      }

      // 检查内容是否实际发生了变化
      if (newContent == null ||
          newContent.isEmpty ||
          newContent == _lastClipboardContent) {
        return;
      }

      // 过滤掉一些不需要的内容
      if (_shouldIgnoreContent(newContent)) {
        return;
      }

      _logger.info(
          '检测到剪贴板变化: ${newContent.substring(0, newContent.length > 50 ? 50 : newContent.length)}');

      // 保存到数据库
      await _clipboardService.addClipboardItem(newContent);

      // 更新最后的剪贴板内容
      _lastClipboardContent = newContent;

      _logger.info('剪贴板内容已保存');
    } catch (e) {
      _logger.severe('处理剪贴板变化失败', e);
      // 不重新抛出异常，避免影响后续监听
    }
  }

  /// 判断是否应该忽略此内容
  bool _shouldIgnoreContent(String content) {
    // 忽略过短的内容
    if (content.length < 2) {
      return true;
    }

    // 忽略纯数字（可能是验证码等敏感信息）
    if (RegExp(r'^\d{4,6}$').hasMatch(content)) {
      return true;
    }

    // 忽略可能的密码（包含特殊字符的短字符串）
    if (content.length < 20 &&
        RegExp(r'[!@#$%^&*()_+\-=\[\]{};:"\\|,.<>?]').hasMatch(content)) {
      return true;
    }

    // 忽略单个字符或符号
    if (content.length == 1) {
      return true;
    }

    return false;
  }

  /// 手动添加剪贴板内容（用于测试）
  Future<void> manuallyAddClipboard(String content) async {
    if (content.isNotEmpty && !_shouldIgnoreContent(content)) {
      await _clipboardService.addClipboardItem(content);
      _lastClipboardContent = content;
      _logger.info('手动添加剪贴板内容: $content');
    }
  }

  /// 获取最后的剪贴板内容
  String? get lastClipboardContent => _lastClipboardContent;

  /// 清理资源
  Future<void> dispose() async {
    await stopWatching();
  }
}
