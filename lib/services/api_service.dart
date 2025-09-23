import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_models.dart';
import '../utils/logger.dart';

class ApiService {
  static final _logger = getLogger('ApiService');
  static const String _defaultBaseUrl = 'http://localhost/api/v1';
  static const String _baseUrlKey = 'api_base_url';
  late Dio _dio;
  String? _token;
  String _currentBaseUrl = _defaultBaseUrl;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    // 在构造函数中不调用异步方法，改为延迟初始化
  }

  // 公共初始化方法
  Future<void> initializeApi() async {
    // 从SharedPreferences加载保存的baseUrl
    await _loadBaseUrl();

    _dio = Dio(BaseOptions(
      baseUrl: _currentBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加请求拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        _logger.info('API请求: ${options.method} ${options.uri}');
        _logger.info('请求头: ${options.headers}');
        if (options.data != null) {
          _logger.info('请求体: ${options.data}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger
            .info('响应: ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) {
        _logger.severe('错误: ${error.message}');
        if (error.response?.statusCode == 401) {
          // Token过期或无效，清除本地存储的token
          _clearToken();
        }
        handler.next(error);
      },
    ));

    // 初始化时加载保存的token
    await _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    _token = token;
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _token = null;
  }

  // BaseUrl 相关方法
  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _currentBaseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    _logger.info('加载保存的BaseUrl: $_currentBaseUrl');
  }

  Future<void> _saveBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl);
    _logger.info('保存BaseUrl: $baseUrl');
  }

  // 获取当前的BaseUrl
  String get currentBaseUrl => _currentBaseUrl;

  // 获取默认的BaseUrl
  String get defaultBaseUrl => _defaultBaseUrl;

  // 更新BaseUrl并重新配置Dio实例
  Future<void> updateBaseUrl(String newBaseUrl) async {
    // 验证URL格式
    if (!_isValidUrl(newBaseUrl)) {
      throw Exception('无效的URL格式');
    }

    // 确保URL以/api/v1结尾
    String formattedUrl = newBaseUrl.trim();
    if (formattedUrl.endsWith('/')) {
      formattedUrl = formattedUrl.substring(0, formattedUrl.length - 1);
    }
    if (!formattedUrl.endsWith('/api/v1')) {
      formattedUrl = '$formattedUrl/api/v1';
    }

    _currentBaseUrl = formattedUrl;
    await _saveBaseUrl(_currentBaseUrl);

    // 重新配置Dio实例
    _dio.options.baseUrl = _currentBaseUrl;
    _logger.info('BaseUrl已更新为: $_currentBaseUrl');
  }

  // 重置BaseUrl为默认值
  Future<void> resetBaseUrl() async {
    await updateBaseUrl(_defaultBaseUrl);
  }

  // 验证URL格式
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // 测试连接到指定的BaseUrl
  Future<bool> testConnection({String? testUrl}) async {
    try {
      final urlToTest = testUrl ?? _currentBaseUrl;
      final tempDio = Dio(BaseOptions(
        baseUrl: urlToTest,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      // 尝试访问健康检查端点
      await tempDio.get('/system/health');
      _logger.info('连接测试成功: $urlToTest');
      return true;
    } catch (e) {
      _logger.warning('连接测试失败: ${testUrl ?? _currentBaseUrl}, 错误: $e');
      return false;
    }
  }

  bool get isAuthenticated => _token != null;

  // 系统接口
  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final response = await _dio.get('/system/health');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getSystemInfo() async {
    try {
      final response = await _dio.get('/system/info');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final response = await _dio.get('/system/stats');
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 认证接口
  Future<AuthResponse> register(
      String username, String email, String password) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'username': username,
        'email': email,
        'password': password,
      });

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveToken(authResponse.token);
      return authResponse;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponse> login(String username, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveToken(authResponse.token);
      return authResponse;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final response = await _dio.post('/auth/refresh');
      final newToken = response.data['token'];
      await _saveToken(newToken);
      return response.data;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/user/logout');
    } catch (e) {
      _logger.warning('登出请求失败: $e');
    } finally {
      await _clearToken();
    }
  }

  // 用户管理接口
  Future<User> getUserProfile() async {
    try {
      final response = await _dio.get('/user/profile');
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 修改密码
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final data = <String, String>{
        'current_password': currentPassword,
        'new_password': newPassword,
      };

      await _dio.put('/user/password', data: data);
      _logger.info('密码修改成功');
    } catch (e) {
      _logger.severe('修改密码失败: $e');
      throw _handleError(e);
    }
  }

  // 剪贴板管理接口
  Future<ClipboardListResponse> getClipboardItems({
    int page = 1,
    int pageSize = 20,
    String? type,
    String? deviceId,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };

      if (type != null) queryParams['type'] = type;
      if (deviceId != null) queryParams['device_id'] = deviceId;
      if (search != null) queryParams['search'] = search;

      final response =
          await _dio.get('/clipboard/items', queryParameters: queryParams);
      return ClipboardListResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<ServerClipboardItem> createClipboardItem({
    required String type,
    required String content,
    String? deviceId,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type,
        'content': content,
      };

      if (deviceId != null) data['device_id'] = deviceId;

      final response = await _dio.post('/clipboard/items', data: data);
      return ServerClipboardItem.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<ServerClipboardItem> getClipboardItem(String id) async {
    try {
      final response = await _dio.get('/clipboard/items/$id');
      return ServerClipboardItem.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<ServerClipboardItem> updateClipboardItem({
    required String id,
    String? content,
    String? type,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (content != null) data['content'] = content;
      if (type != null) data['type'] = type;

      final response = await _dio.put('/clipboard/items/$id', data: data);
      return ServerClipboardItem.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteClipboardItem(String id) async {
    try {
      await _dio.delete('/clipboard/items/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<BatchSyncResponse> batchSync({
    required String deviceId,
    required List<SyncClipboardItem> items,
  }) async {
    try {
      final request = BatchSyncRequest(deviceId: deviceId, items: items);
      final response =
          await _dio.post('/clipboard/sync', data: request.toJson());
      return BatchSyncResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<ClipboardStatistics> getClipboardStatistics() async {
    try {
      final response = await _dio.get('/clipboard/statistics');
      return ClipboardStatistics.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 单项同步接口
  Future<ServerClipboardItem> syncSingleItem({
    required String clientId,
    required String content,
    required String type,
    DateTime? timestamp,
  }) async {
    try {
      final data = <String, dynamic>{
        'client_id': clientId,
        'content': content,
        'type': type,
      };

      if (timestamp != null) {
        data['timestamp'] = timestamp.toIso8601String();
      }

      final response = await _dio.post('/clipboard/sync-single', data: data);
      return ServerClipboardItem.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // 错误处理
  ApiException _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ApiException('连接超时，请检查网络连接');
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;

          String message = '请求失败';
          if (data != null && data is Map && data.containsKey('error')) {
            message = data['error'].toString();
          }

          switch (statusCode) {
            case 400:
              return ApiException('请求参数错误: $message');
            case 401:
              return const ApiException('认证失败，请重新登录');
            case 403:
              return const ApiException('权限不足');
            case 404:
              return const ApiException('资源不存在');
            case 409:
              return ApiException('资源冲突: $message');
            case 413:
              return const ApiException('请求内容过大');
            case 429:
              return const ApiException('请求过于频繁，请稍后再试');
            case 500:
              return const ApiException('服务器内部错误');
            default:
              return ApiException('请求失败: $message');
          }
        case DioExceptionType.cancel:
          return const ApiException('请求已取消');
        case DioExceptionType.unknown:
          if (error.error.toString().contains('SocketException')) {
            return const ApiException('无法连接到服务器，请检查网络连接');
          }
          return ApiException('未知错误: ${error.message}');
        default:
          return ApiException('网络错误: ${error.message}');
      }
    }
    return ApiException('未知错误: $error');
  }
}

// API异常类
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
