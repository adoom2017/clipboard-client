import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_sync_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';
import '../utils/logger.dart';
import 'change_password_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static final _logger = getLogger('SettingsPage');

  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _isConnecting = false;
  bool _isTestingTranslation = false;
  String? _connectionStatus;
  String _selectedModel = SettingsProvider.getAvailableModels().first;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    _baseUrlController.text =
        _apiService.currentBaseUrl.replaceAll('/api/v1', '');

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    _tokenController.text = settingsProvider.translationToken ?? '';
    _selectedModel = settingsProvider.translationModel;
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _connectionStatus = null;
    });

    try {
      String testUrl = _baseUrlController.text.trim();
      if (!testUrl.endsWith('/api/v1')) {
        testUrl = '$testUrl/api/v1';
      }

      final success = await _apiService.testConnection(testUrl: testUrl);

      setState(() {
        _connectionStatus = success ? '连接成功！' : '连接失败，请检查URL是否正确';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = '连接失败: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 保存API服务器设置
      await _apiService.updateBaseUrl(_baseUrlController.text.trim());

      // 保存翻译设置
      await _saveTranslationSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置已保存'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.severe('保存设置失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetToDefault() async {
    await _apiService.resetBaseUrl();
    _loadCurrentSettings();
    setState(() {
      _connectionStatus = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已重置为默认设置'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _testTranslation() async {
    if (_isTestingTranslation) return;

    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先输入API Token'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTestingTranslation = true;
    });

    try {
      const testContent = 'Hello, World!';

      final translationService = TranslationService();
      final result = await translationService.translateText(
        content: testContent,
        token: token,
        model: _selectedModel,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('测试成功'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('原文: ${result.original}'),
                const SizedBox(height: 8),
                Text('翻译: ${result.translation}'),
                const SizedBox(height: 8),
                Text('语言: ${result.sourceLanguage} → ${result.targetLanguage}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        _logger.info('翻译测试成功');
      }
    } catch (e) {
      _logger.warning('翻译测试失败: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('测试失败'),
              ],
            ),
            content: Text('测试失败: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingTranslation = false;
        });
      }
    }
  }

  Future<void> _saveTranslationSettings() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    final token = _tokenController.text.trim();

    try {
      final tokenSuccess = await settingsProvider.setTranslationToken(
        token.isEmpty ? null : token,
      );
      final modelSuccess =
          await settingsProvider.setTranslationModel(_selectedModel);

      if (!tokenSuccess || !modelSuccess) {
        throw Exception('保存翻译设置失败');
      }
    } catch (e) {
      _logger.severe('保存翻译设置失败', e);
      rethrow;
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入服务器地址';
    }

    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return '请输入有效的URL地址 (如: http://192.168.1.100:8080)';
    }

    return null;
  }

  // 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      // 格式化为年月日 时:分
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute';
    }
  }

  void _showTokenHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF9C27B0)),
            SizedBox(width: 8),
            Text('获取API Token'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '如何获取SiliconFlow API Token：',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('1. 访问 https://cloud.siliconflow.cn/'),
              Text('2. 注册并登录账户'),
              Text('3. 进入控制台 -> API密钥'),
              Text('4. 创建新的API密钥'),
              Text('5. 复制密钥并粘贴到此处'),
              SizedBox(height: 12),
              Text(
                '注意：',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.orange),
              ),
              Text('• 请妥善保管您的API密钥'),
              Text('• 密钥具有完整的账户权限'),
              Text('• 建议定期更换密钥'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF007AFF),
            size: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 账户设置卡片
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_circle_outlined,
                            color: Color(0xFF34C759),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '账户设置',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 修改密码选项
                    ListTile(
                      leading: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF007AFF),
                      ),
                      title: const Text('修改密码'),
                      subtitle: const Text('更改您的登录密码'),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordPage(),
                          ),
                        );
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 服务器设置卡片
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.dns_rounded,
                            color: Color(0xFF007AFF),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '服务器设置',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 服务器地址输入框
                    const Text(
                      '服务器地址',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _baseUrlController,
                      validator: _validateUrl,
                      decoration: InputDecoration(
                        hintText: '例如: http://192.168.1.100:8080',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFFF2F2F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF007AFF),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 连接测试按钮
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isConnecting ? null : _testConnection,
                        icon: _isConnecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find, size: 16),
                        label: Text(_isConnecting ? '测试中...' : '测试连接'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF007AFF),
                          side: const BorderSide(color: Color(0xFF007AFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    // 连接状态显示
                    if (_connectionStatus != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _connectionStatus!.contains('成功')
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _connectionStatus!.contains('成功')
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _connectionStatus!.contains('成功')
                                  ? Colors.green
                                  : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _connectionStatus!,
                                style: TextStyle(
                                  color: _connectionStatus!.contains('成功')
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 自动同步开关
                    Consumer<ServerSyncProvider>(
                      builder: (context, syncProvider, child) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.sync,
                                        color: Color(0xFF007AFF),
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '自动同步',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch.adaptive(
                                    value: syncProvider.isAutoSyncEnabled,
                                    onChanged: (value) async {
                                      await syncProvider.setAutoSync(value);

                                      // 显示提示消息
                                      if (mounted) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (value) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    '自动同步已开启，剪贴板内容将自动上传到服务器'),
                                                backgroundColor: Colors.green,
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        });
                                      }
                                    },
                                    activeColor: const Color(0xFF007AFF),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '开启后，剪贴板内容将自动与服务器同步，无需手动点击同步按钮',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (syncProvider.lastSyncTime != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '最后同步时间: ${_formatDateTime(syncProvider.lastSyncTime!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // 重置按钮
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _resetToDefault,
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('重置为默认设置'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 翻译设置卡片
            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, child) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.translate_rounded,
                                color: Color(0xFF9C27B0),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '翻译设置',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (settingsProvider.isTranslationConfigured
                                        ? Colors.green
                                        : Colors.grey)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: settingsProvider
                                              .isTranslationConfigured
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    settingsProvider.isTranslationConfigured
                                        ? '已配置'
                                        : '未配置',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: settingsProvider
                                              .isTranslationConfigured
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // API Token输入框
                        const Text(
                          'SiliconFlow API Token',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _tokenController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '请输入您的API Token',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFFF2F2F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF9C27B0),
                                width: 2,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.help_outline),
                              onPressed: () => _showTokenHelpDialog(),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 模型选择
                        const Text(
                          '翻译模型',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedModel,
                              isExpanded: true,
                              items: SettingsProvider.getAvailableModels()
                                  .map((model) {
                                return DropdownMenuItem<String>(
                                  value: model,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        SettingsProvider.getModelDisplayName(
                                            model),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        model,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedModel = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 测试翻译按钮
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isTestingTranslation ? null : _testTranslation,
                            icon: _isTestingTranslation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.translate, size: 16),
                            label:
                                Text(_isTestingTranslation ? '测试中...' : '测试翻译'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF9C27B0),
                              side: const BorderSide(color: Color(0xFF9C27B0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // 说明卡片
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '使用说明',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '• 默认服务器地址: http://localhost\n'
                      '• 请输入完整的服务器地址，包含协议（http://或https://）\n'
                      '• 如果服务器使用自定义端口，请包含端口号\n'
                      '• 建议先进行连接测试确保服务器可达\n'
                      '• API路径(/api/v1)会自动添加，无需手动输入',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
