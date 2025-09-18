import 'package:flutter/foundation.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkAuthStatus();
  }

  // 检查认证状态
  Future<void> _checkAuthStatus() async {
    _setLoading(true);

    try {
      if (_apiService.isAuthenticated) {
        final user = await _apiService.getUserProfile();
        _setUser(user);
        _setAuthenticated(true);
      }
    } catch (e) {
      debugPrint('检查认证状态失败: $e');
      _setAuthenticated(false);
    } finally {
      _setLoading(false);
    }
  }

  // 用户注册
  Future<bool> register(String username, String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final authResponse =
          await _apiService.register(username, email, password);
      _setUser(authResponse.user);
      _setAuthenticated(true);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 用户登录
  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final authResponse = await _apiService.login(username, password);
      _setUser(authResponse.user);
      _setAuthenticated(true);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 用户登出
  Future<void> logout() async {
    _setLoading(true);

    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint('登出失败: $e');
    } finally {
      _setUser(null);
      _setAuthenticated(false);
      _setLoading(false);
      _clearError();
    }
  }

  // 刷新用户资料
  Future<void> refreshUserProfile() async {
    if (!_isAuthenticated) return;

    try {
      final user = await _apiService.getUserProfile();
      _setUser(user);
    } catch (e) {
      debugPrint('刷新用户资料失败: $e');
      if (e.toString().contains('认证失败')) {
        await logout();
      }
    }
  }

  // 刷新Token
  Future<bool> refreshToken() async {
    try {
      await _apiService.refreshToken();
      return true;
    } catch (e) {
      debugPrint('刷新Token失败: $e');
      await logout();
      return false;
    }
  }

  // 私有方法
  void _setUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  void _setAuthenticated(bool authenticated) {
    _isAuthenticated = authenticated;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // 清除错误信息
  void clearError() {
    _clearError();
  }
}
