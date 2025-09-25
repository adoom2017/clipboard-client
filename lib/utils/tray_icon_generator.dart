import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'logger.dart';

// 创建logger实例
final _logger = getLogger('TrayIconGenerator');

/// 从Flutter assets中提取图标并用于系统托盘
///
/// 这个函数将assets中的图标复制到临时文件，然后使用该文件作为系统托盘图标
Future<void> useAssetIcon() async {
  try {
    // 在不同平台使用不同的处理方式
    String assetPath;
    String tempFileName;

    if (Platform.isWindows) {
      assetPath = 'assets/icon/app_icon.ico';
      tempFileName = 'tray_icon.ico';
    } else if (Platform.isMacOS) {
      assetPath = 'assets/icon/app_icon.png';
      tempFileName = 'tray_icon.png';
    } else {
      // Linux
      assetPath = 'assets/icon/app_icon.png';
      tempFileName = 'tray_icon.png';
    }

    _logger.info('正在使用资源路径: $assetPath');

    // 获取临时目录
    final tempDir = await getTemporaryDirectory();
    final iconPath = '${tempDir.path}${Platform.pathSeparator}$tempFileName';
    final iconFile = File(iconPath);

    _logger.info('临时图标文件路径: $iconPath');

    try {
      // 从assets中加载图标
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      // 将图标写入临时文件
      await iconFile.writeAsBytes(bytes);
      _logger.info('已将资源文件写入临时文件');

      // 设置托盘图标
      await trayManager.setIcon(iconPath);
      _logger.info('使用资源文件设置图标成功: $assetPath -> $iconPath');
      return;
    } catch (assetError) {
      _logger.warning('从Flutter资源加载图标失败: $assetError');
    }

    throw Exception('无法从Flutter资源中提取图标');
  } catch (e) {
    _logger.severe('从资源设置托盘图标失败: $e');
  }
}
