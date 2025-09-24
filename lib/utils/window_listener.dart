import 'package:window_manager/window_manager.dart';
import '../services/window_service.dart';

// 窗口事件监听器
class MyWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    // 点击关闭按钮时隐藏窗口而不是退出应用
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
      WindowService().toggleVisibility(); // 更新窗口服务的可见性状态
    }
  }
}
