import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/clipboard_item.dart';
import '../providers/server_sync_provider.dart';
import '../utils/logger.dart';

class ClipboardItemWidget extends StatefulWidget {
  static final _logger = getLogger('ClipboardItemWidget');

  final ClipboardItem item;
  final VoidCallback? onDelete;
  final VoidCallback? onSync;

  const ClipboardItemWidget({
    super.key,
    required this.item,
    this.onDelete,
    this.onSync,
  });

  @override
  State<ClipboardItemWidget> createState() => _ClipboardItemWidgetState();
}

class _ClipboardItemWidgetState extends State<ClipboardItemWidget> {
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerSyncProvider>(
      builder: (context, syncProvider, child) {
        // 使用服务器对比来检查同步状态
        final isSynced = syncProvider.isItemSynced(widget.item);

        return Container(
          margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _copyToClipboard,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with time and status
                    Row(
                      children: [
                        // Time stamp
                        Expanded(
                          child: Text(
                            widget.item.formattedTime,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        // Sync status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSynced
                                ? const Color(0xFF34C759).withOpacity(0.1)
                                : const Color(0xFFFF9500).withOpacity(0.1),
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
                                  color: isSynced
                                      ? const Color(0xFF34C759)
                                      : const Color(0xFFFF9500),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isSynced ? '已同步' : '待同步',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSynced
                                      ? const Color(0xFF34C759)
                                      : const Color(0xFFFF9500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Content preview with better typography
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Text(
                        _isExpanded ? widget.item.content : widget.item.preview,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          color: Colors.black87,
                        ),
                        maxLines: _isExpanded ? null : 2,
                        overflow: _isExpanded ? null : TextOverflow.ellipsis,
                      ),
                    ),
                    // Action buttons row
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Expand/collapse indicator
                        if (widget.item.content.length > 100)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isExpanded = !_isExpanded;
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: const Color(0xFF007AFF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isExpanded ? '收起' : '展开',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF007AFF),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isSynced) ...[
                              if (_isLoading)
                                Container(
                                  width: 32,
                                  height: 32,
                                  padding: const EdgeInsets.all(6),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF007AFF),
                                    ),
                                  ),
                                )
                              else
                                _buildActionButton(
                                  icon: Icons.cloud_upload_rounded,
                                  onPressed: () => _handleSync(syncProvider),
                                  tooltip: '同步到服务器',
                                  color: const Color(0xFF007AFF),
                                ),
                              const SizedBox(width: 8),
                            ],
                            _buildActionButton(
                              icon: Icons.content_copy_rounded,
                              onPressed: _copyToClipboard,
                              tooltip: '复制到剪贴板',
                              color: const Color(0xFF34C759),
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.delete_outline_rounded,
                              onPressed: widget.onDelete,
                              tooltip: '删除',
                              color: const Color(0xFFFF3B30),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 构建苹果风格的操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required Color color,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  void _handleSync(ServerSyncProvider syncProvider) async {
    if (_isLoading || syncProvider.isItemSynced(widget.item)) return;

    // 在异步操作前获取context相关的引用
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await syncProvider.syncSingleClipboardItem(widget.item);

      if (success && mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('同步成功'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (!success && mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('同步失败: ${syncProvider.errorMessage ?? '未知错误'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('同步出错: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    widget.onSync?.call();
  }

  void _copyToClipboard() async {
    // 复制到系统剪贴板
    await Clipboard.setData(ClipboardData(text: widget.item.content));

    ClipboardItemWidget._logger.info('复制到剪贴板: ${widget.item.id}');

    // 检查当前项目是否已经同步过，如果是，则自动触发新记录的同步
    if (mounted) {
      final syncProvider =
          Provider.of<ServerSyncProvider>(context, listen: false);

      // 检查当前项目是否已同步
      final isSynced = syncProvider.isItemSynced(widget.item);

      if (isSynced) {
        ClipboardItemWidget._logger.info('项目已同步，开始重新同步: ${widget.item.id}');
        // 如果原记录已同步，直接重新同步这个项目到服务器
        // 这样可以更新服务器端的时间戳，表明这个内容被重新使用了
        Future.delayed(const Duration(milliseconds: 500), () async {
          try {
            final success =
                await syncProvider.syncSingleClipboardItem(widget.item);

            if (success && mounted) {
              // 显示重新同步成功的提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.cloud_done_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text('已重新同步到云端'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF007AFF),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );

              // 强制刷新父组件以确保UI状态正确
              widget.onSync?.call();
            }
          } catch (e) {
            ClipboardItemWidget._logger.severe('重新同步失败: ${widget.item.id}', e);
          }
        });
      }

      // 显示复制成功的提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(isSynced ? '已复制，将自动同步到云端' : '已复制到剪贴板'),
            ],
          ),
          backgroundColor: const Color(0xFF34C759),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
