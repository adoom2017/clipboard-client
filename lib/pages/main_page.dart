import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clipboard_item.dart';
import '../providers/auth_provider.dart';
import '../providers/server_sync_provider.dart';
import '../services/clipboard_service.dart';
import '../services/clipboard_watcher_service.dart';
import '../widgets/clipboard_item_widget.dart';
import '../utils/logger.dart';
import 'settings_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  static final _logger = getLogger('MainPage');

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

      _logger.info('服务器数据初始化完成，下载了 $downloadCount 个新项目');

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
      _logger.severe('初始化服务器数据失败', e);
      // 不显示错误提示，避免打扰用户体验
      // 同步状态检查会在后续操作中自动处理
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // 苹果风格的大标题导航栏
            SliverAppBar(
              expandedHeight: 50, // 增加高度以容纳更多内容
              floating: false,
              pinned: true,
              snap: false,
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              automaticallyImplyLeading: false,
              centerTitle: false, // 确保标题不居中
              titleSpacing: 20, // 增加左边距
              // 添加标题区域
              title: SizedBox(
                width: double.infinity,
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_getGreeting()}, ${authProvider.currentUser?.username ?? '用户'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Consumer<ServerSyncProvider>(
                          builder: (context, syncProvider, child) {
                            final localCount =
                                ClipboardService.instance.getAllItems().length;
                            final serverStats =
                                syncProvider.cachedServerStatistics;
                            return Text(
                              '本地 $localCount 条记录${serverStats != null ? ' · 服务器 ${serverStats.totalItems} 条' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                // 剪贴板监听状态指示器
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: _buildStatusButton(
                    icon: _isMonitoring
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color:
                        _isMonitoring ? const Color(0xFF34C759) : Colors.grey,
                    onTap: _toggleMonitoring,
                    tooltip: _isMonitoring ? '剪贴板监听中' : '剪贴板已停止',
                  ),
                ),
                // 同步状态指示器
                Consumer<ServerSyncProvider>(
                  builder: (context, syncProvider, child) {
                    if (syncProvider.isSyncing) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(12),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF007AFF)),
                          ),
                        ),
                      );
                    }
                    return GestureDetector(
                      onLongPress: () {
                        // 长按显示切换自动同步的菜单
                        _showAutoSyncMenu(context, syncProvider);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            _buildStatusButton(
                              icon: syncProvider.isAutoSyncEnabled
                                  ? Icons.sync_rounded // 自动同步开启时显示同步循环图标
                                  : Icons.cloud_sync_rounded, // 手动同步时显示云同步图标
                              color: syncProvider.isAutoSyncEnabled
                                  ? const Color(0xFF34C759) // 自动同步开启时显示绿色
                                  : (syncProvider.lastSyncTime != null
                                      ? const Color(0xFF007AFF) // 已同步蓝色
                                      : Colors.grey), // 未同步灰色
                              onTap: syncProvider.isAutoSyncEnabled
                                  ? () {
                                      // 自动同步开启时，点击显示切换菜单
                                      _showAutoSyncMenu(context, syncProvider);
                                    }
                                  : () => syncProvider
                                      .syncWithServer(), // 手动同步时触发同步
                              tooltip: syncProvider.isAutoSyncEnabled
                                  ? '自动同步已开启${syncProvider.lastSyncTime != null ? '\n最后同步: ${_formatTime(syncProvider.lastSyncTime!)}' : ''}'
                                  : (syncProvider.lastSyncTime != null
                                      ? '最后同步: ${_formatTime(syncProvider.lastSyncTime!)}'
                                      : '点击同步'),
                            ),
                            // 自动同步开启时显示小标记
                            if (syncProvider.isAutoSyncEnabled)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34C759),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // 用户菜单
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: _buildStatusButton(
                    icon: Icons.person_outline_rounded,
                    color: Colors.grey,
                    onTap: () => _showUserMenu(context),
                    tooltip: '用户菜单',
                  ),
                ),
              ],
            ),
            // 苹果风格的分段控制器
            SliverToBoxAdapter(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSegmentButton(
                        '列表',
                        Icons.content_paste_rounded,
                        0,
                        _tabController.index == 0,
                      ),
                    ),
                    Expanded(
                      child: _buildSegmentButton(
                        '同步',
                        Icons.sync_rounded,
                        1,
                        _tabController.index == 1,
                      ),
                    ),
                    Expanded(
                      child: _buildSegmentButton(
                        '统计',
                        Icons.bar_chart_rounded,
                        2,
                        _tabController.index == 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: [
          _buildClipboardTab(),
          _buildSyncTab(),
          _buildStatisticsTab(),
        ][_tabController.index],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _tabController.index == 0
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _toggleMonitoring,
                tooltip: _isMonitoring ? '停止监听' : '开始监听',
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isMonitoring
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey(_isMonitoring),
                    size: 28,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // 构建苹果风格的状态按钮
  Widget _buildStatusButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  // 构建苹果风格的分段按钮
  Widget _buildSegmentButton(
      String title, IconData icon, int index, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF007AFF) : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF007AFF) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示用户菜单
  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 用户信息
            Container(
              padding: const EdgeInsets.all(20),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF007AFF),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authProvider.currentUser?.username ?? '用户',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              authProvider.currentUser?.email ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // 菜单项
            _buildMenuTile(
              icon: Icons.settings_rounded,
              title: '设置',
              onTap: () {
                Navigator.pop(context);
                _handleMenuSelection('settings');
              },
            ),
            _buildMenuTile(
              icon: Icons.logout_rounded,
              title: '登出',
              color: const Color(0xFFFF3B30),
              onTap: () {
                Navigator.pop(context);
                _handleMenuSelection('logout');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 构建菜单项
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? Colors.grey[700],
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color ?? Colors.black,
        ),
      ),
      onTap: onTap,
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
            // 苹果风格的搜索框
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '搜索剪贴板内容...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
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
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.content_paste_rounded,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '暂无剪贴板内容',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '复制一些内容试试吧！',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView.separated(
                        padding: const EdgeInsets.only(
                            bottom: 80), // 添加底部padding避免被FAB遮挡
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: _buildClipboardItem(item),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClipboardItem(ClipboardItem item) {
    return ClipboardItemWidget(
      key: ValueKey(item.id), // 添加唯一key避免Widget复用问题
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
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final success = await syncProvider.deleteItem(item);

    if (mounted) {
      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('项目删除成功'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SettingsPage(),
          ),
        );
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

  // 显示自动同步切换菜单
  void _showAutoSyncMenu(
      BuildContext context, ServerSyncProvider syncProvider) {
    final isAutoEnabled = syncProvider.isAutoSyncEnabled;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                '自动同步设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 菜单项 - 开启自动同步
            ListTile(
              leading: Icon(
                isAutoEnabled ? Icons.check_circle : Icons.circle_outlined,
                color: isAutoEnabled ? const Color(0xFF34C759) : Colors.grey,
              ),
              title: const Text('自动同步开启'),
              subtitle: const Text('剪贴板内容变化时自动同步到云端'),
              onTap: () {
                Navigator.pop(context);
                if (!isAutoEnabled) {
                  syncProvider.setAutoSync(true);
                  // 显示提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('自动同步已开启'),
                      backgroundColor: Color(0xFF34C759),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            // 菜单项 - 关闭自动同步
            ListTile(
              leading: Icon(
                !isAutoEnabled ? Icons.check_circle : Icons.circle_outlined,
                color: !isAutoEnabled ? const Color(0xFF007AFF) : Colors.grey,
              ),
              title: const Text('手动同步模式'),
              subtitle: const Text('需要手动点击同步按钮才会同步到云端'),
              onTap: () {
                Navigator.pop(context);
                if (isAutoEnabled) {
                  syncProvider.setAutoSync(false);
                  // 显示提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已切换为手动同步模式'),
                      backgroundColor: Color(0xFF007AFF),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            // 取消按钮
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 获取问候语
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '早上好';
    } else if (hour < 18) {
      return '下午好';
    } else {
      return '晚上好';
    }
  }
}
