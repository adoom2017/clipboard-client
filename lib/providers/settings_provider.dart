import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class SettingsProvider extends ChangeNotifier {
  static final _logger = getLogger('SettingsProvider');

  // 翻译API相关配置
  static const String _translationTokenKey = 'translation_token';
  static const String _translationModelKey = 'translation_model';
  static const String _defaultModel = 'THUDM/GLM-Z1-9B-0414';

  String? _translationToken;
  String _translationModel = _defaultModel;
  bool _isLoading = false;

  // Getters
  String? get translationToken => _translationToken;
  String get translationModel => _translationModel;
  bool get isLoading => _isLoading;
  bool get isTranslationConfigured => _translationToken?.isNotEmpty == true;

  SettingsProvider() {
    _loadSettings();
  }

  /// 加载所有设置
  Future<void> _loadSettings() async {
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载翻译相关配置
      _translationToken = prefs.getString(_translationTokenKey);
      _translationModel =
          prefs.getString(_translationModelKey) ?? _defaultModel;

      _logger.info(
          '设置加载完成 - Model: $_translationModel, Token配置: ${_translationToken?.isNotEmpty == true}');
    } catch (e) {
      _logger.severe('加载设置失败', e);
    } finally {
      _setLoading(false);
    }
  }

  /// 设置翻译API Token
  Future<bool> setTranslationToken(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (token?.isEmpty == true) {
        await prefs.remove(_translationTokenKey);
        _translationToken = null;
      } else {
        await prefs.setString(_translationTokenKey, token!);
        _translationToken = token;
      }

      notifyListeners();
      _logger.info('翻译Token更新成功: ${token?.isNotEmpty == true}');
      return true;
    } catch (e) {
      _logger.severe('保存翻译Token失败', e);
      return false;
    }
  }

  /// 设置翻译模型
  Future<bool> setTranslationModel(String model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_translationModelKey, model);

      _translationModel = model;
      notifyListeners();

      _logger.info('翻译模型更新成功: $model');
      return true;
    } catch (e) {
      _logger.severe('保存翻译模型失败', e);
      return false;
    }
  }

  /// 重置翻译配置
  Future<bool> resetTranslationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_translationTokenKey);
      await prefs.remove(_translationModelKey);

      _translationToken = null;
      _translationModel = _defaultModel;
      notifyListeners();

      _logger.info('翻译配置已重置');
      return true;
    } catch (e) {
      _logger.severe('重置翻译配置失败', e);
      return false;
    }
  }

  /// 验证翻译配置是否完整
  bool validateTranslationConfig() {
    final isValid =
        _translationToken?.isNotEmpty == true && _translationModel.isNotEmpty;

    if (!isValid) {
      _logger.warning(
          '翻译配置不完整 - Token: ${_translationToken?.isNotEmpty}, Model: ${_translationModel.isNotEmpty}');
    }

    return isValid;
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 获取可用的翻译模型列表
  static List<String> getAvailableModels() {
    return [
      'THUDM/GLM-Z1-9B-0414',
      'Qwen/QwQ-32B',
      'THUDM/glm-4-9b-chat',
      'Qwen/Qwen2.5-14B-Instruct',
      'microsoft/DialoGPT-medium',
    ];
  }

  /// 获取模型显示名称
  static String getModelDisplayName(String model) {
    switch (model) {
      case 'THUDM/GLM-Z1-9B-0414':
        return 'GLM-Z1-9B (默认)';
      case 'Qwen/QwQ-32B':
        return 'QwQ-32B';
      case 'THUDM/glm-4-9b-chat':
        return 'GLM-4-9B';
      case 'Qwen/Qwen2.5-14B-Instruct':
        return 'Qwen2.5-14B';
      case 'microsoft/DialoGPT-medium':
        return 'DialoGPT Medium';
      default:
        return model;
    }
  }
}
