import 'package:hive/hive.dart';

part 'clipboard_item.g.dart';

@HiveType(typeId: 0)
class ClipboardItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String content;

  @HiveField(2)
  DateTime timestamp;

  @HiveField(3)
  bool isSynced;

  @HiveField(4)
  String? syncedAt;

  @HiveField(5)
  ClipboardType type;

  @HiveField(6)
  String? serverId;

  ClipboardItem({
    required this.id,
    required this.content,
    required this.timestamp,
    this.isSynced = false,
    this.syncedAt,
    this.type = ClipboardType.text,
    this.serverId,
  });

  /// 获取内容预览，限制长度避免界面过长
  String get preview {
    if (content.length <= 100) {
      return content;
    }
    return '${content.substring(0, 97)}...';
  }

  /// 获取格式化的时间戳
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else {
      return '${timestamp.month}月${timestamp.day}日 ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 转换为JSON格式，用于网络传输
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isSynced': isSynced,
      'syncedAt': syncedAt,
      'type': type.toString(),
      'serverId': serverId,
    };
  }

  /// 从JSON创建ClipboardItem
  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    return ClipboardItem(
      id: json['id'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isSynced: json['isSynced'] ?? false,
      syncedAt: json['syncedAt'],
      type: ClipboardType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ClipboardType.text,
      ),
      serverId: json['serverId'],
    );
  }

  @override
  String toString() {
    return 'ClipboardItem{id: $id, content: ${content.length > 20 ? '${content.substring(0, 20)}...' : content}, timestamp: $timestamp, isSynced: $isSynced}';
  }
}

@HiveType(typeId: 1)
enum ClipboardType {
  @HiveField(0)
  text,

  @HiveField(1)
  image,

  @HiveField(2)
  file,
}
