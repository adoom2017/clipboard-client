import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/clipboard_item.dart';

class NetworkService {
  static const String _defaultBaseUrl =
      'https://api.example.com'; // 替换为实际的服务器地址
  static NetworkService? _instance;

  final String baseUrl;
  final Duration timeout;
  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  NetworkService._internal({
    this.baseUrl = _defaultBaseUrl,
    this.timeout = const Duration(seconds: 30),
  });

  static NetworkService get instance {
    _instance ??= NetworkService._internal();
    return _instance!;
  }

  /// 创建自定义配置的NetworkService实例
  factory NetworkService.custom({
    String baseUrl = _defaultBaseUrl,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return NetworkService._internal(baseUrl: baseUrl, timeout: timeout);
  }

  /// 设置认证令牌
  void setAuthToken(String token) {
    _defaultHeaders['Authorization'] = 'Bearer $token';
  }

  /// 移除认证令牌
  void removeAuthToken() {
    _defaultHeaders.remove('Authorization');
  }

  /// 同步单个剪贴板项目到服务器
  Future<SyncResult> syncClipboardItem(ClipboardItem item) async {
    try {
      final url = Uri.parse('$baseUrl/clipboard/items');
      final response = await http
          .post(
            url,
            headers: _defaultHeaders,
            body: jsonEncode(item.toJson()),
          )
          .timeout(timeout);

      return _handleSyncResponse(response, item);
    } catch (e) {
      return SyncResult(
        success: false,
        error: _getErrorMessage(e),
        item: item,
      );
    }
  }

  /// 批量同步剪贴板项目到服务器
  Future<List<SyncResult>> syncMultipleItems(List<ClipboardItem> items) async {
    final results = <SyncResult>[];

    try {
      final url = Uri.parse('$baseUrl/clipboard/items/batch');
      final requestData = {
        'items': items.map((item) => item.toJson()).toList(),
      };

      final response = await http
          .post(
            url,
            headers: _defaultHeaders,
            body: jsonEncode(requestData),
          )
          .timeout(timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final syncedItems = responseData['synced'] as List? ?? [];

        // 处理成功同步的项目
        for (final item in items) {
          final isSynced = syncedItems.any((synced) => synced['id'] == item.id);
          results.add(SyncResult(
            success: isSynced,
            error: isSynced ? null : '同步失败',
            item: item,
          ));
        }
      } else {
        // 如果批量同步失败，标记所有项目为失败
        for (final item in items) {
          results.add(SyncResult(
            success: false,
            error: '批量同步失败: ${response.statusCode}',
            item: item,
          ));
        }
      }
    } catch (e) {
      // 如果出现异常，标记所有项目为失败
      for (final item in items) {
        results.add(SyncResult(
          success: false,
          error: _getErrorMessage(e),
          item: item,
        ));
      }
    }

    return results;
  }

  /// 从服务器获取剪贴板项目
  Future<List<ClipboardItem>> fetchClipboardItems({
    DateTime? since,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (since != null) {
        queryParams['since'] = since.toIso8601String();
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }

      final url = Uri.parse('$baseUrl/clipboard/items').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http
          .get(
            url,
            headers: _defaultHeaders,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final items = responseData['items'] as List? ?? [];

        return items
            .map((item) => ClipboardItem.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw HttpException('Failed to fetch items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(
          'Failed to fetch clipboard items: ${_getErrorMessage(e)}');
    }
  }

  /// 从服务器删除剪贴板项目
  Future<bool> deleteClipboardItem(String itemId) async {
    try {
      final url = Uri.parse('$baseUrl/clipboard/items/$itemId');
      final response = await http
          .delete(
            url,
            headers: _defaultHeaders,
          )
          .timeout(timeout);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// 测试网络连接
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$baseUrl/health');
      final response = await http
          .get(
            url,
            headers: _defaultHeaders,
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 用户认证（如果需要）
  Future<AuthResult> authenticate(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final token = responseData['token'] as String?;

        if (token != null) {
          setAuthToken(token);
          return AuthResult(success: true, token: token);
        }
      }

      return AuthResult(
        success: false,
        error: '认证失败: ${response.statusCode}',
      );
    } catch (e) {
      return AuthResult(
        success: false,
        error: '认证错误: ${_getErrorMessage(e)}',
      );
    }
  }

  /// 处理同步响应
  SyncResult _handleSyncResponse(http.Response response, ClipboardItem item) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return SyncResult(
          success: true,
          item: item,
          serverId: responseData['id'] as String?,
        );
      } catch (e) {
        return SyncResult(
          success: true, // 状态码成功，即使解析响应失败也认为同步成功
          item: item,
        );
      }
    } else {
      return SyncResult(
        success: false,
        error: '同步失败: HTTP ${response.statusCode}',
        item: item,
      );
    }
  }

  /// 获取错误消息
  String _getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return '网络连接失败';
    } else if (error is HttpException) {
      return 'HTTP错误: ${error.message}';
    } else if (error is FormatException) {
      return '数据格式错误';
    } else if (error.toString().contains('timeout')) {
      return '请求超时';
    } else {
      return error.toString();
    }
  }
}

/// 同步结果类
class SyncResult {
  final bool success;
  final String? error;
  final ClipboardItem item;
  final String? serverId;

  SyncResult({
    required this.success,
    this.error,
    required this.item,
    this.serverId,
  });

  @override
  String toString() {
    return 'SyncResult{success: $success, error: $error, item: ${item.id}}';
  }
}

/// 认证结果类
class AuthResult {
  final bool success;
  final String? error;
  final String? token;

  AuthResult({
    required this.success,
    this.error,
    this.token,
  });

  @override
  String toString() {
    return 'AuthResult{success: $success, error: $error, hasToken: ${token != null}}';
  }
}
