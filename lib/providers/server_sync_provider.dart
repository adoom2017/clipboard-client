import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clipboard_item.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import '../services/clipboard_service.dart';
import '../utils/logger.dart';

class ServerSyncProvider extends ChangeNotifier {
  static final _logger = getLogger('ServerSyncProvider');

  final ApiService _apiService = ApiService();
  final ClipboardService _clipboardService = ClipboardService.instance;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _errorMessage;

  // 缓存的服务器统计信息
  ClipboardStatistics? _cachedServerStatistics;
  bool _isLoadingStatistics = false;

  // 服务器项目缓存，用于比对同步状态
  final Map<String, ServerClipboardItem> _serverItemsCache = {};
  DateTime? _lastCacheUpdateTime;

  // 设备ID - 用于标识当前设备
  String _deviceId = 'flutter-client-${DateTime.now().millisecondsSinceEpoch}';

  // 自动同步配置
  bool _isAutoSyncEnabled = false;

  // Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;
  String get deviceId => _deviceId;
  ClipboardStatistics? get cachedServerStatistics => _cachedServerStatistics;
  bool get isLoadingStatistics => _isLoadingStatistics;
  bool get isAutoSyncEnabled => _isAutoSyncEnabled;

  ServerSyncProvider() {
    _loadSettings().then((_) {
      // 如果自动同步已开启，初始化剪贴板监听器
      if (_isAutoSyncEnabled) {
        _setupClipboardListener();
      }
    });
  }

  // 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id') ?? _deviceId;

    final lastSyncTimestamp = prefs.getInt('last_sync_time');
    if (lastSyncTimestamp != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimestamp);
    }

    // 加载自动同步设置
    _isAutoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;

    // 保存设备ID
    await prefs.setString('device_id', _deviceId);

    notifyListeners();
  }

  // 设置自动同步状态
  Future<void> setAutoSync(bool enabled) async {
    if (_isAutoSyncEnabled == enabled) return;

    _isAutoSyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', enabled);

    _logger.info('自动同步已${enabled ? "开启" : "关闭"}');

    if (enabled) {
      // 如果开启了自动同步，立即进行一次同步
      await syncWithServer();

      // 在这里开启监听剪贴板变化
      _setupClipboardListener();
    } else {
      // 如果关闭自动同步，移除监听器
      _removeClipboardListener();
    }

    notifyListeners();
  }

  // 刷新服务器数据缓存
  Future<void> refreshServerItemsCache() async {
    try {
      _logger.info('开始刷新服务器数据缓存');

      // 获取服务器端的剪贴板项目
      final response = await _apiService.getClipboardItems(
        page: 1,
        pageSize: 1000, // 获取大量数据以便完整比对
      );

      // 更新缓存
      _serverItemsCache.clear();
      for (final serverItem in response.items) {
        // 使用内容的哈希作为key来匹配
        final contentKey = _generateContentKey(serverItem.content);
        _serverItemsCache[contentKey] = serverItem;
      }

      _lastCacheUpdateTime = DateTime.now();
      _logger.info('服务器数据缓存刷新完成，共 ${_serverItemsCache.length} 项');

      notifyListeners();
    } catch (e) {
      _logger.severe('刷新服务器缓存失败', e);
    }
  }

  // 同步下载服务器剪贴板项目到本地
  Future<int> downloadServerItems() async {
    if (_isSyncing) return 0;

    // 避免在构建期间调用 notifyListeners
    _isSyncing = true;
    _errorMessage = null;

    // 使用 WidgetsBinding.instance.addPostFrameCallback 来延迟通知
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    int downloadCount = 0;

    try {
      _logger.info('开始下载服务器剪贴板项目到本地');

      // 获取服务器端的剪贴板项目
      final response = await _apiService.getClipboardItems(
        page: 1,
        pageSize: 1000,
      );

      final localItems = _clipboardService.getAllItems();
      final localContentKeys =
          localItems.map((item) => _generateContentKey(item.content)).toSet();

      // 只下载本地没有的项目
      for (final serverItem in response.items) {
        final contentKey = _generateContentKey(serverItem.content);

        if (!localContentKeys.contains(contentKey)) {
          // 创建本地剪贴板项目
          final localItem = ClipboardItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: serverItem.content,
            type: _parseClipboardType(serverItem.type),
            timestamp: serverItem.timestamp,
            isSynced: true, // 从服务器下载的项目标记为已同步
            serverId: serverItem.id, // 设置服务器ID用于后续删除
          );

          // 添加到本地数据库
          await _clipboardService.addItem(localItem);
          downloadCount++;
        }
      }

      // 更新缓存
      _serverItemsCache.clear();
      for (final serverItem in response.items) {
        final contentKey = _generateContentKey(serverItem.content);
        _serverItemsCache[contentKey] = serverItem;
      }
      _lastCacheUpdateTime = DateTime.now();

      _logger.info('服务器项目下载完成，新增 $downloadCount 项');
      return downloadCount;
    } catch (e) {
      _logger.severe('下载服务器项目失败', e);
      _errorMessage = '下载服务器项目失败: $e';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return 0;
    } finally {
      _isSyncing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // 生成内容的唯一标识key
  String _generateContentKey(String content) {
    // 使用内容的哈希值作为唯一标识
    return content.hashCode.toString();
  }

  // 检查单个项目是否已同步
  bool isItemSynced(ClipboardItem item) {
    final contentKey = _generateContentKey(item.content);
    final serverItem = _serverItemsCache[contentKey];

    if (serverItem == null) {
      return false; // 服务器端没有这个项目
    }

    // 比较时间戳，如果服务器端的时间戳晚于或等于本地时间戳，认为已同步
    final serverTimestamp = serverItem.timestamp;
    final localTimestamp = item.timestamp;

    return serverTimestamp.isAfter(localTimestamp) ||
        serverTimestamp.isAtSameMomentAs(localTimestamp);
  }

  // 获取需要同步的项目列表
  Future<List<ClipboardItem>> getUnsyncedItems() async {
    final allItems = _clipboardService.getAllItems();
    final unsyncedItems = <ClipboardItem>[];

    for (final item in allItems) {
      if (!isItemSynced(item)) {
        unsyncedItems.add(item);
      }
    }

    return unsyncedItems;
  }

  // 批量检查和更新同步状态
  Future<void> updateSyncStatus() async {
    if (_serverItemsCache.isEmpty ||
        _lastCacheUpdateTime == null ||
        DateTime.now().difference(_lastCacheUpdateTime!).inMinutes > 5) {
      // 如果缓存为空或者缓存过期（5分钟），先刷新缓存
      await refreshServerItemsCache();
    }

    // 通知UI更新，因为同步状态可能已改变
    notifyListeners();
  }

  // 单个项目同步方法
  Future<bool> syncSingleClipboardItem(ClipboardItem item) async {
    if (_isSyncing) return false;

    _setSyncing(true);
    _clearError();

    try {
      _logger.info('开始同步项目: ${item.id}');

      // 检查内容长度
      const maxContentLength = 512 * 1024; // 512KB
      if (item.content.length > maxContentLength) {
        _logger.warning('内容过长，无法同步: ${item.content.length}字符');
        _setError('内容过长，无法同步（${item.content.length}字符）');
        return false;
      }

      // 调用单项同步API
      final syncedItem = await _apiService.syncSingleItem(
        clientId: item.id,
        content: item.content,
        type: item.type.name,
        timestamp: item.timestamp,
      );

      // 更新服务器缓存
      final contentKey = _generateContentKey(item.content);
      _serverItemsCache[contentKey] = syncedItem;

      // 更新本地项目的服务器ID
      item.serverId = syncedItem.id;
      await item.save();

      // 更新最后同步时间
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);

      _logger.info('项目同步成功: ${item.id} -> ${syncedItem.id}');
      return true;
    } catch (e) {
      _logger.severe('项目同步失败: ${item.id}', e);
      _setError('同步失败: ${e.toString()}');
      return false;
    } finally {
      _setSyncing(false);
    }
  }

  // 刷新服务器统计信息（简化的同步，不做数据同步，只获取统计信息）
  Future<bool> syncWithServer() async {
    if (_isSyncing) return false;

    _setSyncing(true);
    _clearError();

    try {
      // 刷新服务器统计信息
      await getServerStatistics();

      // 更新最后同步时间
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);

      _logger.info('统计信息同步完成');
      return true;
    } catch (e) {
      _setError('同步失败: ${e.toString()}');
      return false;
    } finally {
      _setSyncing(false);
    }
  }

  // 获取服务器统计信息
  Future<ClipboardStatistics?> getServerStatistics() async {
    _isLoadingStatistics = true;
    notifyListeners();

    try {
      final statistics = await _apiService.getClipboardStatistics();
      _cachedServerStatistics = statistics;
      _clearError(); // 清除错误信息
      return statistics;
    } catch (e) {
      _setError('获取统计信息失败: ${e.toString()}');
      return null;
    } finally {
      _isLoadingStatistics = false;
      notifyListeners();
    }
  }

  // 删除服务器上的项目
  Future<bool> deleteServerItem(String serverId) async {
    try {
      await _apiService.deleteClipboardItem(serverId);
      return true;
    } catch (e) {
      _setError('删除服务器项目失败: ${e.toString()}');
      return false;
    }
  }

  // 删除项目（同时删除本地和服务器）
  Future<bool> deleteItem(ClipboardItem localItem) async {
    _isSyncing = true;
    _errorMessage = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // 首先删除本地项目
      await _clipboardService.deleteItem(localItem);
      _logger.info('本地项目删除成功: ${localItem.id}');

      // 如果有服务器 ID，也删除服务器上的项目
      if (localItem.serverId != null && localItem.serverId!.isNotEmpty) {
        final serverDeleted = await deleteServerItem(localItem.serverId!);
        if (serverDeleted) {
          _logger.info('服务器项目删除成功: ${localItem.serverId}');
          // 从缓存中移除
          _serverItemsCache
              .removeWhere((key, value) => value.id == localItem.serverId);
        } else {
          _logger.warning('服务器项目删除失败: ${localItem.serverId}');
          // 即使服务器删除失败，本地已删除，可以继续
        }
      }

      // 更新同步状态缓存
      await refreshServerItemsCache();

      return true;
    } catch (e) {
      _logger.severe('删除项目失败', e);
      _errorMessage = '删除项目失败: $e';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return false;
    } finally {
      _isSyncing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // 创建服务器项目
  Future<ServerClipboardItem?> createServerItem({
    required String type,
    required String content,
  }) async {
    try {
      return await _apiService.createClipboardItem(
        type: type,
        content: content,
        deviceId: _deviceId,
      );
    } catch (e) {
      _setError('创建服务器项目失败: ${e.toString()}');
      return null;
    }
  }

  // 解析剪贴板类型
  ClipboardType _parseClipboardType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'text':
        return ClipboardType.text;
      case 'image':
        return ClipboardType.image;
      case 'file':
        return ClipboardType.file;
      default:
        return ClipboardType.text;
    }
  }

  // 私有方法
  void _setSyncing(bool syncing) {
    _isSyncing = syncing;
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

  // 设置剪贴板监听器
  void _setupClipboardListener() {
    // 监听ClipboardService的变化
    _clipboardService.addListener(_onClipboardChanged);
    _logger.info('剪贴板监听已启用');
  }

  // 移除剪贴板监听器
  void _removeClipboardListener() {
    _clipboardService.removeListener(_onClipboardChanged);
    _logger.info('剪贴板监听已禁用');
  }

  // 剪贴板变化处理
  void _onClipboardChanged() async {
    if (!_isAutoSyncEnabled || _isSyncing) {
      return; // 如果自动同步未开启或正在同步中，则不处理
    }

    _logger.info('检测到剪贴板变化，准备自动同步');

    // 获取未同步项目
    final unsyncedItems = await getUnsyncedItems();

    if (unsyncedItems.isEmpty) {
      _logger.info('没有需要同步的项目');
      return;
    }

    _logger.info('开始自动同步，共 ${unsyncedItems.length} 项待同步');

    // 同步每个未同步的项目
    for (final item in unsyncedItems) {
      await syncSingleClipboardItem(item);
    }

    // 更新最后同步时间
    _lastSyncTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);

    _logger.info('自动同步完成');
  }
}
