import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clipboard_item.dart';
import '../services/clipboard_service.dart';
import '../providers/server_sync_provider.dart';

class SearchDelegate extends MaterialPageRoute<ClipboardItem?> {
  SearchDelegate()
      : super(
          builder: (context) => const SearchPage(),
          settings: const RouteSettings(name: '/search'),
        );
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ClipboardService _clipboardService = ClipboardService.instance;
  List<ClipboardItem> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // 初始显示所有项目
    _searchResults = _clipboardService.getAllItems();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _searchResults = _clipboardService.getAllItems();
      } else {
        _searchResults = _clipboardService.searchItems(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索剪贴板内容...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索结果统计
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _isSearching
                      ? '找到 ${_searchResults.length} 条结果'
                      : '共 ${_searchResults.length} 条记录',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          // 搜索结果列表
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSearching
                              ? Icons.search_off
                              : Icons.content_paste_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSearching ? '没有找到匹配的内容' : '暂无剪贴板记录',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final item = _searchResults[index];
                      return _buildSearchResultItem(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(ClipboardItem item) {
    final query = _searchController.text.toLowerCase();

    return Consumer<ServerSyncProvider>(
      builder: (context, syncProvider, child) {
        final isSynced = syncProvider.isItemSynced(item);

        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSynced ? Colors.green : Colors.orange,
              child: Icon(
                isSynced ? Icons.cloud_done : Icons.content_paste,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: RichText(
              text: _buildHighlightedText(
                item.preview,
                query,
                Theme.of(context).textTheme.bodyLarge,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(item.formattedTime),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSynced)
                  IconButton(
                    icon: const Icon(Icons.cloud_upload, size: 20),
                    onPressed: () => _syncItem(item),
                    tooltip: '同步到服务器',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _deleteItem(item),
                  tooltip: '删除',
                ),
              ],
            ),
            onTap: () {
              Navigator.of(context).pop(item);
            },
          ),
        );
      },
    );
  }

  TextSpan _buildHighlightedText(String text, String query, TextStyle? style) {
    if (query.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    int start = 0;
    int index = lowerText.indexOf(query);

    while (index != -1) {
      // 添加匹配前的文本
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: style,
        ));
      }

      // 添加高亮的匹配文本
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style?.copyWith(
          backgroundColor: Colors.yellow.withOpacity(0.7),
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
      index = lowerText.indexOf(query, start);
    }

    // 添加剩余的文本
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }

    return TextSpan(children: spans);
  }

  void _syncItem(ClipboardItem item) async {
    // 这里可以实现同步逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('同步功能待实现')),
    );
  }

  void _deleteItem(ClipboardItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条剪贴板记录吗？这将同时删除本地和云端的数据。'),
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
      ),
    );

    if (confirmed == true) {
      try {
        final syncProvider =
            Provider.of<ServerSyncProvider>(context, listen: false);
        final success = await syncProvider.deleteItem(item);

        if (success) {
          setState(() {
            _searchResults.remove(item);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已删除剪贴板记录（本地和云端）')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('删除失败: ${syncProvider.errorMessage ?? "未知错误"}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
