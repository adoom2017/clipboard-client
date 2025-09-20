import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_models.dart';
import '../utils/logger.dart';

class ApiService {
  static final _logger = getLogger('ApiService');
  static const String baseUrl = 'http://localhost/api/v1';
  late final Dio _dio;
  String? _token;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
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
    _loadToken();
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
