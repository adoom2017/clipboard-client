# 剪贴板监听工具 (Clipboard Auto)

一个功能强大的 Flutter 剪贴板监听工具，能够自动监听系统剪贴板变化，提供本地存储和服务器同步功能。

## ✨ 特性

- 🎯 **自动监听**: 实时监听系统剪贴板变化
- 💾 **本地存储**: 使用 Hive 数据库持久化存储数据
- ☁️ **云端同步**: 支持将数据同步到远程服务器
- 🔍 **智能搜索**: 全文搜索剪贴板历史记录
- 📊 **数据统计**: 提供使用统计和分析功能
- 🛡️ **隐私保护**: 智能过滤敏感信息
- 🎨 **现代界面**: Material Design 3 界面设计
- 🌙 **深色模式**: 支持浅色和深色主题

## 📱 支持平台

- ✅ Android
- ✅ iOS
- ✅ Windows
- ✅ macOS
- ✅ Linux
- ✅ Web

## 🚀 快速开始

### 环境要求

- Flutter SDK: >=3.5.4
- Dart SDK: >=3.5.4

### 安装依赖

```bash
flutter pub get
```

### 生成代码

```bash
flutter packages pub run build_runner build
```

### 运行应用

```bash
flutter run
```

## 🏗️ 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   └── clipboard_item.dart   # 剪贴板项目模型
├── services/                 # 业务服务
│   ├── clipboard_service.dart         # 数据服务
│   ├── clipboard_watcher_service.dart  # 监听服务
│   └── network_service.dart           # 网络服务
└── widgets/                  # UI 组件
    ├── clipboard_item_widget.dart  # 剪贴板项目组件
    ├── search_page.dart           # 搜索页面
    └── statistics_panel.dart      # 统计面板
```

## 📦 核心依赖

```yaml
dependencies:
  flutter:
    sdk: flutter
  hive: ^2.2.3                    # 本地数据库
  hive_flutter: ^1.1.0            # Hive Flutter 适配器
  clipboard_watcher: ^0.3.0       # 剪贴板监听
  http: ^1.5.0                    # HTTP 请求
  path_provider: ^2.1.5           # 路径获取

dev_dependencies:
  hive_generator: ^2.0.1          # Hive 代码生成器
  build_runner: ^2.4.11           # 构建工具
```

## 🔧 配置

### 服务器配置

在 `lib/services/network_service.dart` 中修改服务器地址：

```dart
static const String _defaultBaseUrl = 'https://your-api-server.com';
```

### 过滤规则配置

在 `lib/services/clipboard_watcher_service.dart` 中自定义内容过滤规则：

```dart
bool _shouldIgnoreContent(String content) {
  // 添加自定义过滤逻辑
  return false;
}
```

## 🛠️ API 接口

### 同步剪贴板项目

```http
POST /clipboard/items
Content-Type: application/json

{
  "id": "string",
  "content": "string",
  "timestamp": "2023-01-01T00:00:00.000Z",
  "type": "text"
}
```

### 获取剪贴板项目

```http
GET /clipboard/items?since=2023-01-01T00:00:00.000Z&limit=50
```

### 删除剪贴板项目

```http
DELETE /clipboard/items/{id}
```

## 🎨 界面预览

### 主界面
- 显示所有剪贴板历史记录
- 支持删除和同步操作
- 实时状态显示

### 搜索界面
- 全文搜索功能
- 关键词高亮显示
- 实时搜索结果

### 统计界面
- 数据使用统计
- 同步状态分析
- 存储空间统计

## 🔐 权限说明

### Android
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 📝 开发指南

### 添加新功能

1. 在对应的 service 中添加业务逻辑
2. 更新数据模型（如需要）
3. 创建或更新 UI 组件
4. 添加相应的测试

### 数据库迁移

当数据模型发生变化时：

1. 更新模型类
2. 增加 typeId 版本号
3. 运行代码生成: `flutter packages pub run build_runner build`

### 自定义主题

在 `main.dart` 中修改主题配置：

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  useMaterial3: true,
)
```

## 🧪 测试

### 运行单元测试

```bash
flutter test
```

### 运行集成测试

```bash
flutter test integration_test/
```

## 📦 构建发布

### Android APK

```bash
flutter build apk --release
```

### iOS IPA

```bash
flutter build ios --release
```

### Windows

```bash
flutter build windows --release
```

## 🤝 贡献指南

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 MIT 许可证。详细信息请查看 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- [Flutter](https://flutter.dev/) - UI 框架
- [Hive](https://pub.dev/packages/hive) - 本地数据库
- [clipboard_watcher](https://pub.dev/packages/clipboard_watcher) - 剪贴板监听

## 📞 联系方式

如有问题或建议，请通过以下方式联系：

- 提交 [Issue](../../issues)
- 发送邮件至 developer@example.com

---

## 🎉 项目状态

**✅ 完整实现完成！**

该项目已完整实现了剪贴板监听和服务器同步的所有核心功能：

### 已完成功能
- ✅ **完整的 Flutter 客户端** - 包含登录、主页、同步等完整界面
- ✅ **Go 后端服务** - RESTful API，支持用户认证和数据同步
- ✅ **用户认证系统** - JWT token 认证，支持注册和登录
- ✅ **剪贴板监听** - 自动监听系统剪贴板变化
- ✅ **本地数据存储** - 使用 Hive 进行本地持久化
- ✅ **双向数据同步** - 支持上传本地数据和下载服务器数据
- ✅ **现代化 UI** - Material Design 3.0 风格界面
- ✅ **状态管理** - 使用 Provider 进行状态管理
- ✅ **完整的 API 文档** - 包括 OpenAPI 规范、Postman 集合等

### 技术实现
- **前端**: Flutter + Provider 状态管理 + Hive 本地存储
- **后端**: Go + Gin 框架 + SQLite 数据库
- **通信**: RESTful API + JWT 认证
- **同步**: 双向数据同步机制

### 可运行状态
项目当前已经可以正常运行：
1. 后端服务器已测试并运行在 `http://localhost:8080`
2. Flutter 客户端已成功编译并运行
3. 所有核心功能均已实现且测试通过

**注意**: 这是一个演示项目，展示了 Flutter + Go 全栈开发的完整实现。在生产环境使用前请做好安全性评估。
