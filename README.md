# 剪贴板同步工具 (Clipboard Auto)

一个功能简单的跨平台剪贴板监听、存储和同步应用，基于 Flutter 开发，支持本地存储、云端同步。

## ✨ 功能特色

### 🔄 实时剪贴板监听
- **实时监听**：自动监听系统剪贴板变化，无需手动操作
- **智能去重**：避免重复内容的保存，节省存储空间
- **一键切换**：支持监听状态的快速开启/关闭

### 💾 本地数据存储
- **高性能数据库**：使用 Hive NoSQL 数据库进行本地持久化存储
- **快速查询**：毫秒级数据读写性能，支持大量历史记录
- **存储优化**：自动清理过长内容，防止数据库膨胀

### ☁️ 云端同步功能
- **双向同步**：支持本地与服务器之间的双向数据同步
- **实时上传**：新剪贴板内容自动上传到云端
- **批量下载**：一键下载服务器上的所有剪贴板数据
- **冲突处理**：智能处理本地与云端的数据冲突

## 🏗️ 项目架构

### 技术栈
- **前端框架**：Flutter 3.5.4+
- **本地存储**：Hive NoSQL 数据库

### 项目结构

```
lib/
├── main.dart                          # 应用程序入口
├── models/                            # 数据模型层
│   ├── clipboard_item.dart            # 剪贴板数据模型
│   └── api_models.dart                # API 数据模型
├── services/                          # 业务服务层
│   ├── clipboard_service.dart         # 剪贴板数据服务
│   ├── clipboard_watcher_service.dart # 剪贴板监听服务
│   └── api_service.dart               # API 网络服务
├── providers/                         # 状态管理层
│   ├── auth_provider.dart             # 认证状态管理
│   └── server_sync_provider.dart      # 同步状态管理
├── pages/                             # 页面视图层
│   ├── login_page.dart                # 登录注册页面
│   ├── main_page.dart                 # 主页面（剪贴板、同步、统计）
│   └── settings_page.dart             # 设置页面
├── widgets/                           # UI 组件层
│   ├── clipboard_item_widget.dart     # 剪贴板项目组件
│   ├── statistics_panel.dart          # 统计面板组件
│   └── search_page.dart               # 搜索页面组件
└── utils/                             # 工具类
    └── logger.dart                    # 日志工具类
```

## 🚀 快速开始

### 系统要求

- **Flutter SDK**: 3.5.4 或更高版本
- **Dart SDK**: 3.0.0 或更高版本
- **支持平台**: Windows, macOS, Linux, iOS, Android, Web
- **最低系统版本**:
  - iOS 12.0+
  - Android API 21 (Android 5.0)+
  - Windows 10+
  - macOS 10.14+

### 安装步骤

1. **克隆项目仓库**
   ```bash
   git clone https://github.com/your-repo/clipboard-auto.git
   cd clipboard-auto/client
   ```

2. **安装 Flutter 依赖**
   ```bash
   flutter pub get
   ```

3. **生成必要的代码文件**
   ```bash
   dart run build_runner build
   ```

4. **运行应用程序**
   ```bash
   # 开发模式运行
   flutter run
   
   # 指定设备运行
   flutter run -d windows
   flutter run -d macos
   flutter run -d chrome
   ```

### 构建发布版本

```bash
# 构建 Windows 应用
flutter build windows --release

# 构建 macOS 应用
flutter build macos --release

# 构建 Linux 应用
flutter build linux --release

# 构建 Android APK
flutter build apk --release

# 构建 iOS 应用（需要 macOS 环境）
flutter build ios --release

# 构建 Web 应用
flutter build web --release
```

## ⚙️ 配置说明

### 服务器配置

应用支持动态配置服务器地址：

1. **首次启动配置**：
   - 在登录页面点击右上角设置按钮
   - 输入服务器地址（如：`http://localhost:8080`）
   - 点击测试连接确认服务器可用
   - 保存配置后进行登录

2. **应用内配置**：
   - 登录后在设置页面修改服务器地址
   - 支持实时连接测试
   - 配置变更后自动保存

### 数据存储位置

本地数据文件存储位置：

- **Windows**: `%USERPROFILE%\AppData\Roaming\clipboard_auto`
- **macOS**: `~/Library/Application Support/clipboard_auto`
- **Linux**: `~/.local/share/clipboard_auto`
- **iOS**: 应用沙盒 Documents 目录
- **Android**: 应用私有数据目录

### 系统权限配置

#### Windows
- 应用会自动请求剪贴板访问权限
- Windows Defender 可能需要添加信任

#### macOS
- 在"系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能"中添加应用
- 可能需要在"输入监控"权限中也添加应用

### 代码规范

- 遵循 Dart/Flutter 官方代码规范
- 使用 `flutter_lints` 进行代码质量检查
- 所有公共方法都有详细的文档注释
- 错误处理使用 try-catch 并记录到日志系统


## 📄 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本项目
2. 创建功能分支：`git checkout -b feature/amazing-feature`
3. 提交更改：`git commit -m 'Add amazing feature'`
4. 推送到分支：`git push origin feature/amazing-feature`
5. 打开 Pull Request

### 贡献规范

- 确保代码通过所有测试
- 遵循项目的代码规范
- 为新功能添加相应的测试用例
- 更新相关文档

## 🙏 致谢

- [Flutter](https://flutter.dev/) - 跨平台 UI 框架
- [Hive](https://pub.dev/packages/hive) - 高性能 NoSQL 数据库
- [clipboard_watcher](https://pub.dev/packages/clipboard_watcher) - 剪贴板监听插件
- [Provider](https://pub.dev/packages/provider) - Flutter 状态管理库
- [Dio](https://pub.dev/packages/dio) - 强大的 HTTP 客户端

## 📞 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 [GitHub Issue](https://github.com/your-repo/clipboard-auto/issues)
- 发送邮件至：developer@example.com
- 项目讨论群：[加入讨论](https://your-chat-link.com)
