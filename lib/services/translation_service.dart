import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/logger.dart';

class TranslationService {
  static final _logger = getLogger('TranslationService');
  static const String _baseUrl =
      'https://api.siliconflow.cn/v1/chat/completions';
  static const Duration _timeout = Duration(seconds: 30);

  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  late Dio _dio;

  void _initDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加日志拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.info('翻译请求: ${options.method} ${options.uri}');
        // 不记录完整的Authorization头，只记录是否存在
        final hasAuth = options.headers['Authorization'] != null;
        _logger.info('认证头存在: $hasAuth');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.info('翻译响应: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        _logger.severe('翻译请求错误: ${error.message}');
        handler.next(error);
      },
    ));
  }

  /// 翻译文本内容
  ///
  /// [content] 要翻译的文本内容
  /// [token] SiliconFlow API token
  /// [model] 使用的模型名称
  ///
  /// 返回翻译结果的Map，包含原文和翻译
  Future<TranslationResult> translateText({
    required String content,
    required String token,
    required String model,
  }) async {
    if (content.trim().isEmpty) {
      throw TranslationException('翻译内容不能为空');
    }

    _initDio();

    try {
      // 构造提示词
      final prompt = _buildTranslationPrompt(content);

      final requestData = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.3,
        'max_tokens': 4000,
      };

      _logger.info('发送翻译请求 - Model: $model, Content length: ${content.length}');

      final response = await _dio.post(
        _baseUrl,
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return _parseTranslationResponse(response.data, content);
      } else {
        throw TranslationException('翻译服务响应异常: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _logger.severe('翻译请求失败', e);

      if (e.response?.statusCode == 401) {
        throw TranslationException('API Token无效，请检查配置');
      } else if (e.response?.statusCode == 429) {
        throw TranslationException('请求过于频繁，请稍后再试');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw TranslationException('连接超时，请检查网络连接');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw TranslationException('请求超时，请稍后再试');
      } else {
        throw TranslationException('网络错误: ${e.message}');
      }
    } catch (e) {
      _logger.severe('翻译处理失败', e);
      throw TranslationException('翻译失败: $e');
    }
  }

  /// 构建翻译提示词
  String _buildTranslationPrompt(String content) {
    return '''你是一个翻译专家，可以根据用户输入的内容，自动判断语言，进行中文和英文的转换。如果发现用户输入的为中文则翻译成英文，如果发现用户输入的为英文则翻译成中文。

请翻译由{}中包括的内容：{$content}

输出格式为JSON，包含以下字段：
- "original": 原文内容
- "translation": 翻译后的内容
- "source_language": 原文语言（"zh"或"en"）
- "target_language": 目标语言（"zh"或"en"）

请确保返回的是有效的JSON格式。''';
  }

  /// 解析翻译响应
  TranslationResult _parseTranslationResponse(
      Map<String, dynamic> responseData, String originalContent) {
    try {
      final choices = responseData['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw TranslationException('翻译响应格式异常：缺少choices');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      if (message == null) {
        throw TranslationException('翻译响应格式异常：缺少message');
      }

      final content = message['content'] as String?;
      if (content == null || content.isEmpty) {
        throw TranslationException('翻译响应格式异常：缺少content');
      }

      _logger.info('原始翻译响应: $content');

      // 尝试解析JSON响应
      Map<String, dynamic> translationJson;
      try {
        // 提取可能的JSON内容
        String jsonContent = content.trim();

        // 如果内容被包装在代码块中，提取出来
        if (jsonContent.startsWith('```json')) {
          jsonContent = jsonContent.substring(7);
        }
        if (jsonContent.startsWith('```')) {
          jsonContent = jsonContent.substring(3);
        }
        if (jsonContent.endsWith('```')) {
          jsonContent = jsonContent.substring(0, jsonContent.length - 3);
        }

        jsonContent = jsonContent.trim();
        translationJson = json.decode(jsonContent);
      } catch (e) {
        _logger.warning('JSON解析失败，尝试提取翻译内容: $e');

        // 如果JSON解析失败，尝试简单的内容提取
        return TranslationResult(
          original: originalContent,
          translation: content.trim(),
          sourceLanguage: _detectLanguage(originalContent),
          targetLanguage: _detectLanguage(content),
        );
      }

      // 从JSON中提取数据
      final translation = translationJson['translation'] as String? ??
          translationJson['translated'] as String? ??
          content.trim();

      final sourceLanguage = translationJson['source_language'] as String? ??
          _detectLanguage(originalContent);

      final targetLanguage = translationJson['target_language'] as String? ??
          _detectLanguage(translation);

      return TranslationResult(
        original: originalContent,
        translation: translation,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    } catch (e) {
      _logger.severe('解析翻译响应失败', e);
      throw TranslationException('解析翻译结果失败: $e');
    }
  }

  /// 简单的语言检测
  String _detectLanguage(String text) {
    // 检查是否包含中文字符
    final chineseRegex = RegExp(r'[\u4e00-\u9fff]');
    if (chineseRegex.hasMatch(text)) {
      return 'zh';
    }
    return 'en';
  }

  /// 验证翻译配置
  static bool isConfigValid(String? token, String? model) {
    return token?.isNotEmpty == true && model?.isNotEmpty == true;
  }
}

/// 翻译结果类
class TranslationResult {
  final String original;
  final String translation;
  final String sourceLanguage;
  final String targetLanguage;

  TranslationResult({
    required this.original,
    required this.translation,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  String toString() {
    return 'TranslationResult(original: $original, translation: $translation, '
        'sourceLanguage: $sourceLanguage, targetLanguage: $targetLanguage)';
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'translation': translation,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
    };
  }

  /// 从JSON创建
  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      original: json['original'] as String,
      translation: json['translation'] as String,
      sourceLanguage: json['source_language'] as String,
      targetLanguage: json['target_language'] as String,
    );
  }
}

/// 翻译异常类
class TranslationException implements Exception {
  final String message;

  TranslationException(this.message);

  @override
  String toString() => 'TranslationException: $message';
}
