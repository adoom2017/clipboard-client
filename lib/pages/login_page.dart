import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // 构建iOS风格的输入框
  Widget _buildIOSTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF000000),
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF8E8E93),
            size: 22,
          ),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF007AFF),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return CustomScrollView(
              slivers: [
                // iOS风格的大标题
                SliverAppBar(
                  backgroundColor: const Color(0xFFF2F2F7),
                  elevation: 0,
                  expandedHeight: 120,
                  pinned: false,
                  automaticallyImplyLeading: false,
                  actions: [
                    // 服务器设置按钮
                    Padding(
                      padding: const EdgeInsets.only(right: 16, top: 16),
                      child: IconButton(
                        onPressed: _showServerSettings,
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: Color(0xFF007AFF),
                          size: 24,
                        ),
                        tooltip: '服务器设置',
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    titlePadding: const EdgeInsets.only(bottom: 16),
                    title: Text(
                      _isLoginMode ? '登录' : '注册',
                      style: const TextStyle(
                        color: Color(0xFF000000),
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    expandedTitleScale: 1.0,
                  ),
                ),

                // 登录表单内容
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007AFF),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF007AFF)
                                            .withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.content_paste_rounded,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),

                          // 用户名输入框
                          _buildIOSTextField(
                            controller: _usernameController,
                            labelText: '用户名',
                            prefixIcon: Icons.person_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入用户名';
                              }
                              if (value.length < 3) {
                                return '用户名至少需要3个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // 邮箱输入框（仅注册时显示）
                          if (!_isLoginMode) ...[
                            _buildIOSTextField(
                              controller: _emailController,
                              labelText: '邮箱',
                              prefixIcon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '请输入邮箱地址';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                                  return '请输入有效的邮箱地址';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 密码输入框
                          _buildIOSTextField(
                            controller: _passwordController,
                            labelText: '密码',
                            prefixIcon: Icons.lock_rounded,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: const Color(0xFF8E8E93),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入密码';
                              }
                              if (value.length < 6) {
                                return '密码至少需要6个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // 错误提示
                          if (authProvider.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_rounded,
                                      color: Colors.red.shade700, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      authProvider.errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close_rounded,
                                        size: 18, color: Colors.red.shade700),
                                    onPressed: authProvider.clearError,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // 登录/注册按钮
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF007AFF), Color(0xFF0056CC)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF007AFF).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  authProvider.isLoading ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isLoginMode ? '登录' : '注册',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 切换登录/注册模式
                          TextButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isLoginMode = !_isLoginMode;
                                    });
                                    authProvider.clearError();
                                  },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              _isLoginMode ? '还没有账号？点击注册' : '已有账号？点击登录',
                              style: const TextStyle(
                                color: Color(0xFF007AFF),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // 服务器状态提示
                          const _ServerStatusIndicator(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 显示服务器设置对话框
  void _showServerSettings() {
    final logger = getLogger('LoginPage');
    final apiService = ApiService();

    showDialog(
      context: context,
      builder: (context) => _ServerSettingsDialog(
        apiService: apiService,
        logger: logger,
      ),
    );
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = false;

    if (_isLoginMode) {
      success = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await authProvider.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }
}

class _ServerStatusIndicator extends StatefulWidget {
  const _ServerStatusIndicator();

  @override
  State<_ServerStatusIndicator> createState() => _ServerStatusIndicatorState();
}

class _ServerStatusIndicatorState extends State<_ServerStatusIndicator> {
  bool? _isServerOnline;

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
  }

  Future<void> _checkServerStatus() async {
    // 这里可以添加检查服务器状态的逻辑
    setState(() {
      _isServerOnline = true; // 假设服务器在线
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isServerOnline == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isServerOnline! ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isServerOnline! ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isServerOnline! ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isServerOnline! ? '服务器在线' : '服务器离线',
            style: TextStyle(
              color: _isServerOnline!
                  ? Colors.green.shade700
                  : Colors.red.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// 服务器设置对话框
class _ServerSettingsDialog extends StatefulWidget {
  final ApiService apiService;
  final dynamic logger;

  const _ServerSettingsDialog({
    required this.apiService,
    required this.logger,
  });

  @override
  State<_ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<_ServerSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrlController;

  bool _isLoading = false;
  bool _isConnecting = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.apiService.currentBaseUrl.replaceAll('/api/v1', ''),
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
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

      final success = await widget.apiService.testConnection(testUrl: testUrl);

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
      await widget.apiService.updateBaseUrl(_baseUrlController.text.trim());

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('服务器设置已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      widget.logger.severe('保存设置失败', e);
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
    await widget.apiService.resetBaseUrl();
    _baseUrlController.text =
        widget.apiService.currentBaseUrl.replaceAll('/api/v1', '');
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
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
                  const Expanded(
                    child: Text(
                      '服务器设置',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 内容区域
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '服务器地址',
                      style: TextStyle(
                        fontSize: 16,
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
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF007AFF),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

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
                            : const Icon(Icons.wifi_find, size: 18),
                        label: Text(_isConnecting ? '测试中...' : '测试连接'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF007AFF),
                          side: const BorderSide(color: Color(0xFF007AFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

                    const SizedBox(height: 20),

                    // 按钮行
                    Row(
                      children: [
                        // 重置按钮
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _resetToDefault,
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('重置'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 保存按钮
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveSettings,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save, size: 16),
                            label: Text(_isLoading ? '保存中...' : '保存'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007AFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
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
