import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clipboard_item.dart';
import '../providers/auth_provider.dart';
import '../providers/server_sync_provider.dart';
import '../services/clipboard_service.dart';
import '../services/clipboard_watcher_service.dart';
import '../widgets/clipboard_item_widget.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ClipboardWatcherService _clipboardWatcher;

  String _searchQuery = '';
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _clipboardWatcher = ClipboardWatcherService.instance;
    _initClipboardWatcher();
    // 登录成功后自动开始监听剪贴板
    _autoStartMonitoring();

    // 延迟执行服务器数据初始化，避免在构建期间调用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServerData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    // 确保在销毁时停止监听
    _clipboardWatcher.stopWatching();
    super.dispose();
  }

  void _initClipboardWatcher() {
    // ClipboardWatcherService 已经自动处理剪贴板变化并保存到数据库
    // ClipboardService 现在继承了 ChangeNotifier，会自动通知UI更新
  }

  /// 自动开始监听剪贴板
  void _autoStartMonitoring() async {
    try {
      await _clipboardWatcher.startWatching();
      setState(() {
        _isMonitoring = true;
      });

      // 显示提示信息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('剪贴板监听已自动开启'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 如果自动启动失败，显示错误信息但不影响程序运行
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text('自动启动剪贴板监听失败: $e')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 初始化服务器数据
  void _initializeServerData() async {
    try {
      final syncProvider =
          Provider.of<ServerSyncProvider>(context, listen: false);

      // 下载服务器剪贴板项目到本地
      final downloadCount = await syncProvider.downloadServerItems();

      // 可选：获取服务器统计信息
      await syncProvider.getServerStatistics();

      debugPrint('服务器数据初始化完成，下载了 $downloadCount 个新项目');

      // 如果下载了新项目，显示提示
      if (downloadCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已从服务器同步 $downloadCount 个剪贴板项目'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('初始化服务器数据失败: $e');
      // 不显示错误提示，避免打扰用户体验
      // 同步状态检查会在后续操作中自动处理
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('剪贴板同步工具'),
        actions: [
          // 剪贴板监听状态指示器
          IconButton(
            icon: Icon(
              _isMonitoring ? Icons.visibility : Icons.visibility_off,
              color: _isMonitoring ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleMonitoring,
            tooltip: _isMonitoring ? '剪贴板监听中 (点击停止)' : '剪贴板已停止 (点击开始)',
          ),
          // 同步状态指示器
          Consumer<ServerSyncProvider>(
            builder: (context, syncProvider, child) {
              if (syncProvider.isSyncing) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return IconButton(
                icon: Icon(
                  Icons.cloud_sync,
                  color: syncProvider.lastSyncTime != null
                      ? Colors.green
                      : Colors.grey,
                ),
                onPressed: () => syncProvider.syncWithServer(),
                tooltip: syncProvider.lastSyncTime != null
                    ? '最后同步: ${_formatTime(syncProvider.lastSyncTime!)}'
                    : '点击同步',
              );
            },
          ),
          // 用户菜单
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 8),
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, child) {
                        return Text(authProvider.currentUser?.username ?? '用户');
                      },
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('设置'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('登出'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.content_paste), text: '剪贴板'),
            Tab(icon: Icon(Icons.sync), text: '同步'),
            Tab(icon: Icon(Icons.bar_chart), text: '统计'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClipboardTab(),
          _buildSyncTab(),
          _buildStatisticsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _toggleMonitoring,
              tooltip: _isMonitoring ? '停止监听' : '开始监听',
              child: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }

  Widget _buildClipboardTab() {
    return Consumer<ClipboardService>(
      builder: (context, clipboardService, child) {
        // 获取项目列表
        List<ClipboardItem> items;
        if (_searchQuery.isEmpty) {
          items = clipboardService.getAllItems();
        } else {
          items = clipboardService.searchItems(_searchQuery);
        }

        return Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索剪贴板内容...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (query) {
                  setState(() {
                    _searchQuery = query;
                  });
                },
              ),
            ),

            // 剪贴板列表
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.content_paste,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            '暂无剪贴板内容',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '复制一些内容试试吧！',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _buildClipboardItem(item);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClipboardItem(ClipboardItem item) {
    return ClipboardItemWidget(
      item: item,
      onDelete: () => _handleItemAction('delete', item),
      onSync: () {
        // 同步完成后刷新页面
        setState(() {});
      },
    );
  }

  Widget _buildSyncTab() {
    return Consumer<ServerSyncProvider>(
      builder: (context, syncProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 同步设置
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '同步设置',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      ListTile(
                        title: Text('手动同步'),
                        subtitle: Text('只支持手动触发同步操作'),
                        leading: Icon(Icons.touch_app),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 同步状态
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '同步状态',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          syncProvider.isSyncing
                              ? Icons.sync
                              : Icons.sync_disabled,
                          color: syncProvider.isSyncing
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        title: Text(syncProvider.isSyncing ? '同步中...' : '空闲'),
                        subtitle: syncProvider.lastSyncTime != null
                            ? Text(
                                '最后同步: ${_formatTime(syncProvider.lastSyncTime!)}')
                            : const Text('尚未同步'),
                      ),
                      if (syncProvider.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  syncProvider.errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 手动同步按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: syncProvider.isSyncing
                      ? null
                      : syncProvider.syncWithServer,
                  icon: const Icon(Icons.sync),
                  label: const Text('立即同步'),
                ),
              ),

              const SizedBox(height: 12),

              // 从服务器下载按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: syncProvider.isSyncing
                      ? null
                      : () => _downloadFromServer(syncProvider),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('从服务器下载'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 从服务器下载剪贴板项目
  void _downloadFromServer(ServerSyncProvider syncProvider) async {
    try {
      final downloadCount = await syncProvider.downloadServerItems();

      if (mounted) {
        if (downloadCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功从服务器下载了 $downloadCount 个剪贴板项目'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('没有发现新的剪贴板项目'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildStatisticsTab() {
    return Consumer2<ServerSyncProvider, ClipboardService>(
      builder: (context, syncProvider, clipboardService, child) {
        // 获取所有剪贴板项目
        final allItems = clipboardService.getAllItems();

        // 使用ServerSyncProvider计算真实的同步状态统计
        final syncedItems =
            allItems.where((item) => syncProvider.isItemSynced(item)).toList();
        final unsyncedItems =
            allItems.where((item) => !syncProvider.isItemSynced(item)).toList();
        final totalSize =
            allItems.fold<int>(0, (sum, item) => sum + item.content.length);

        final stats = {
          'totalItems': allItems.length,
          'syncedItems': syncedItems.length,
          'unsyncedItems': unsyncedItems.length,
          'totalContentSize': totalSize,
        };

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 刷新缓存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // 刷新服务器缓存来确保同步状态准确
                    await syncProvider.refreshServerItemsCache();
                    // 强制重新构建UI
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新同步状态'),
                ),
              ),

              const SizedBox(height: 16),

              // 本地统计
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本地统计 (基于服务器对比)',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow('总项目数', '${stats['totalItems']}'),
                      _buildStatRow('已同步', '${stats['syncedItems']}'),
                      _buildStatRow('未同步', '${stats['unsyncedItems']}'),
                      _buildStatRow('内容总大小', '${stats['totalContentSize']} 字符'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 获取服务器统计按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _fetchServerStatistics(syncProvider),
                  icon: const Icon(Icons.cloud_download),
                  label: const Text('获取服务器统计'),
                ),
              ),

              const SizedBox(height: 16),

              // 服务器统计 - 只有在有数据时才显示
              if (syncProvider.cachedServerStatistics != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '服务器统计',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow('服务器项目数',
                            '${syncProvider.cachedServerStatistics!.totalItems}'),
                        _buildStatRow('已同步项目',
                            '${syncProvider.cachedServerStatistics!.syncedItems}'),
                        _buildStatRow('未同步项目',
                            '${syncProvider.cachedServerStatistics!.unsyncedItems}'),
                        _buildStatRow('服务器内容大小',
                            '${syncProvider.cachedServerStatistics!.totalContentSize} 字符'),
                      ],
                    ),
                  ),
                ),

              // 显示加载状态
              if (syncProvider.isLoadingStatistics)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(ClipboardType type) {
    switch (type) {
      case ClipboardType.text:
        return Icons.text_fields;
      case ClipboardType.image:
        return Icons.image;
      case ClipboardType.file:
        return Icons.file_present;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else {
      return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  void _toggleMonitoring() async {
    try {
      if (_isMonitoring) {
        await _clipboardWatcher.stopWatching();
        setState(() {
          _isMonitoring = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.pause_circle, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('剪贴板监听已停止'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await _clipboardWatcher.startWatching();
        setState(() {
          _isMonitoring = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.play_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('剪贴板监听已开启'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('切换监听状态失败: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _copyToClipboard(String content) async {
    // 这里可以添加复制到系统剪贴板的逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  void _handleItemAction(String action, ClipboardItem item) async {
    switch (action) {
      case 'copy':
        _copyToClipboard(item.content);
        break;
      case 'delete':
        await _showDeleteConfirmDialog(item);
        break;
    }
  }

  // 显示删除确认对话框
  Future<void> _showDeleteConfirmDialog(ClipboardItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除此剪贴板项目吗？这将同时删除本地和云端的数据。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteItem(item);
    }
  }

  // 删除项目（本地和云端）
  Future<void> _deleteItem(ClipboardItem item) async {
    final syncProvider =
        Provider.of<ServerSyncProvider>(context, listen: false);

    final success = await syncProvider.deleteItem(item);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('项目删除成功'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: ${syncProvider.errorMessage ?? "未知错误"}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _fetchServerStatistics(ServerSyncProvider syncProvider) async {
    try {
      await syncProvider.getServerStatistics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('服务器统计信息已更新'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取统计信息失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleMenuSelection(String value) async {
    switch (value) {
      case 'profile':
        // 显示用户资料
        break;
      case 'settings':
        // 打开设置页面
        break;
      case 'logout':
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        break;
    }
  }
}
