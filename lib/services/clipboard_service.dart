import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/clipboard_item.dart';

class ClipboardService extends ChangeNotifier {
  static const String _boxName = 'clipboard_items';
  static ClipboardService? _instance;

  ClipboardService._internal();

  static ClipboardService get instance {
    _instance ??= ClipboardService._internal();
    return _instance!;
  }

  /// 获取剪贴板数据盒子
  Box<ClipboardItem> get _box => Hive.box<ClipboardItem>(_boxName);

  /// 添加新的剪贴板项目
  Future<void> addClipboardItem(String content) async {
    // 检查内容长度，超过512KB的内容不保存
    const maxContentLength = 512 * 1024; // 512KB
    if (content.length > maxContentLength) {
      debugPrint('剪贴板内容过长(${content.length}字符)，跳过保存');
      return;
    }

    // 检查是否已存在相同内容的项目
    final existingItems = _box.values.where((item) => item.content == content);
    if (existingItems.isNotEmpty) {
      // 如果存在相同内容，更新时间戳
      final existingItem = existingItems.first;
      existingItem.timestamp = DateTime.now();
      await existingItem.save();
      notifyListeners(); // 通知UI更新
      return;
    }

    // 创建新项目
    final item = ClipboardItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      timestamp: DateTime.now(),
      isSynced: false,
      type: _getClipboardType(content),
    );

    await _box.add(item);
    notifyListeners(); // 通知UI更新
  }

  /// 直接添加剪贴板项目
  Future<void> addClipboardItemDirect(ClipboardItem item) async {
    // 检查是否已存在相同内容的项目
    final existingItems =
        _box.values.where((existing) => existing.content == item.content);
    if (existingItems.isNotEmpty) {
      // 如果存在相同内容，更新时间戳
      final existingItem = existingItems.first;
      existingItem.timestamp = DateTime.now();
      await existingItem.save();
      notifyListeners(); // 通知UI更新
      return;
    }

    await _box.add(item);
    notifyListeners(); // 通知UI更新
  }

  /// 清理过长的剪贴板项目
  Future<void> cleanupLongContent() async {
    const maxContentLength = 512 * 1024; // 512KB
    final itemsToDelete = <int>[];

    for (int i = 0; i < _box.length; i++) {
      final item = _box.getAt(i);
      if (item != null && item.content.length > maxContentLength) {
        itemsToDelete.add(i);
      }
    }

    // 从后往前删除，避免索引错乱
    for (int i = itemsToDelete.length - 1; i >= 0; i--) {
      await _box.deleteAt(itemsToDelete[i]);
    }

    if (itemsToDelete.isNotEmpty) {
      debugPrint('清理了 ${itemsToDelete.length} 个过长的剪贴板项目');
      notifyListeners();
    }
  }

  List<ClipboardItem> getAllItems() {
    final items = _box.values.toList();
    // 按时间倒序排列
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  /// 获取未同步的项目
  List<ClipboardItem> getUnsyncedItems() {
    return _box.values.where((item) => !item.isSynced).toList();
  }

  /// 删除指定项目
  Future<void> deleteItem(ClipboardItem item) async {
    await item.delete();
    notifyListeners(); // 通知UI更新
  }

  /// 删除所有项目
  Future<void> deleteAllItems() async {
    await _box.clear();
    notifyListeners(); // 通知UI更新
  }

  /// 标记项目为已同步
  Future<void> markAsSynced(ClipboardItem item) async {
    item.isSynced = true;
    // 不再设置syncedAt字段，因为服务器端已移除该字段
    await item.save();
    notifyListeners(); // 通知UI更新
  }

  /// 更新项目内容
  Future<void> updateItem(ClipboardItem item, String newContent) async {
    item.content = newContent;
    item.timestamp = DateTime.now();
    item.isSynced = false; // 更新后需要重新同步
    // 不再设置syncedAt字段
    await item.save();
    notifyListeners(); // 通知UI更新
  }

  /// 更新项目（新版本，支持完整更新）
  Future<void> updateItemComplete(ClipboardItem item) async {
    await item.save();
    notifyListeners(); // 通知UI更新
  }

  /// 添加项目（新版本）
  Future<void> addItem(ClipboardItem item) async {
    // 检查是否已存在相同内容的项目
    final existingItems =
        _box.values.where((existing) => existing.content == item.content);
    if (existingItems.isNotEmpty) {
      // 如果存在相同内容，更新时间戳
      final existingItem = existingItems.first;
      existingItem.timestamp = DateTime.now();
      await existingItem.save();
      notifyListeners(); // 通知UI更新
      return;
    }

    await _box.add(item);
    notifyListeners(); // 通知UI更新
  }

  /// 根据服务器ID查找项目
  ClipboardItem? getItemByServerId(String serverId) {
    return _box.values.cast<ClipboardItem?>().firstWhere(
          (item) => item?.serverId == serverId,
          orElse: () => null,
        );
  }

  /// 获取项目总数
  int get itemCount => _box.length;

  /// 获取未同步项目数量
  int get unsyncedCount => getUnsyncedItems().length;

  /// 搜索包含指定文本的项目
  List<ClipboardItem> searchItems(String query) {
    if (query.isEmpty) return getAllItems();

    return _box.values
        .where(
            (item) => item.content.toLowerCase().contains(query.toLowerCase()))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 获取指定时间范围内的项目
  List<ClipboardItem> getItemsInRange(DateTime start, DateTime end) {
    return _box.values
        .where((item) =>
            item.timestamp.isAfter(start) && item.timestamp.isBefore(end))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 清理旧数据（保留最近N天的数据）
  Future<void> cleanOldData({int daysToKeep = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final itemsToDelete = _box.values
        .where((item) => item.timestamp.isBefore(cutoffDate))
        .toList();

    for (final item in itemsToDelete) {
      await item.delete();
    }
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    final items = _box.values;
    final syncedCount = items.where((item) => item.isSynced).length;
    final totalSize =
        items.fold<int>(0, (sum, item) => sum + item.content.length);

    return {
      'totalItems': items.length,
      'syncedItems': syncedCount,
      'unsyncedItems': items.length - syncedCount,
      'totalContentSize': totalSize,
      'averageContentSize': items.isNotEmpty ? totalSize / items.length : 0,
      'oldestItem': items.isNotEmpty
          ? items
              .map((item) => item.timestamp)
              .reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      'newestItem': items.isNotEmpty
          ? items
              .map((item) => item.timestamp)
              .reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
    };
  }

  /// 根据内容判断剪贴板类型
  ClipboardType _getClipboardType(String content) {
    // 简单的类型检测逻辑
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return ClipboardType.text; // URL也算文本
    }

    // 检查是否为文件路径
    if (RegExp(r'^[a-zA-Z]:\\.*|^/.*').hasMatch(content)) {
      return ClipboardType.file;
    }

    // 默认为文本类型
    return ClipboardType.text;
  }

  /// 导出数据为JSON格式
  Map<String, dynamic> exportToJson() {
    final items = getAllItems();
    return {
      'exportTime': DateTime.now().toIso8601String(),
      'itemCount': items.length,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  /// 从JSON导入数据
  Future<int> importFromJson(Map<String, dynamic> jsonData) async {
    if (!jsonData.containsKey('items') || jsonData['items'] is! List) {
      throw ArgumentError('Invalid JSON format');
    }

    final items = jsonData['items'] as List;
    int importedCount = 0;

    for (final itemData in items) {
      try {
        final item = ClipboardItem.fromJson(itemData as Map<String, dynamic>);
        // 检查是否已存在相同ID的项目
        final existingItem = _box.values.cast<ClipboardItem?>().firstWhere(
            (existing) => existing?.id == item.id,
            orElse: () => null);

        if (existingItem == null) {
          await _box.add(item);
          importedCount++;
        }
      } catch (e) {
        // 跳过无效的项目
        continue;
      }
    }

    return importedCount;
  }
}
