import 'package:json_annotation/json_annotation.dart';

part 'api_models.g.dart';

// 用户模型
@JsonSerializable()
class User {
  final String id;
  final String username;
  final String email;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'last_login')
  final DateTime? lastLogin;
  @JsonKey(name: 'total_items')
  final int? totalItems;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.createdAt,
    this.lastLogin,
    this.totalItems,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

// 认证响应模型
@JsonSerializable()
class AuthResponse {
  final String token;
  final User user;

  const AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

// 服务器剪贴板项目模型
@JsonSerializable()
class ServerClipboardItem {
  final String id;
  final String content;
  final String type;
  @JsonKey(name: 'is_synced')
  final bool isSynced;
  @JsonKey(name: 'synced_at')
  final DateTime? syncedAt;
  final DateTime timestamp;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const ServerClipboardItem({
    required this.id,
    required this.content,
    required this.type,
    required this.isSynced,
    this.syncedAt,
    required this.timestamp,
    required this.createdAt,
  });

  factory ServerClipboardItem.fromJson(Map<String, dynamic> json) =>
      _$ServerClipboardItemFromJson(json);
  Map<String, dynamic> toJson() => _$ServerClipboardItemToJson(this);
}

// 剪贴板列表响应
@JsonSerializable()
class ClipboardListResponse {
  final List<ServerClipboardItem> items;
  final int total;
  final int page;
  @JsonKey(name: 'page_size')
  final int pageSize;
  @JsonKey(name: 'total_pages')
  final int totalPages;
  @JsonKey(name: 'has_next')
  final bool hasNext;
  @JsonKey(name: 'has_prev')
  final bool hasPrev;

  const ClipboardListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory ClipboardListResponse.fromJson(Map<String, dynamic> json) =>
      _$ClipboardListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ClipboardListResponseToJson(this);
}

// 批量同步请求
@JsonSerializable(explicitToJson: true)
class BatchSyncRequest {
  @JsonKey(name: 'device_id')
  final String deviceId;
  final List<SyncClipboardItem> items;

  const BatchSyncRequest({
    required this.deviceId,
    required this.items,
  });

  factory BatchSyncRequest.fromJson(Map<String, dynamic> json) =>
      _$BatchSyncRequestFromJson(json);
  Map<String, dynamic> toJson() => _$BatchSyncRequestToJson(this);
}

// 同步剪贴板项目
@JsonSerializable()
class SyncClipboardItem {
  final String type;
  final String content;
  final DateTime timestamp;

  const SyncClipboardItem({
    required this.type,
    required this.content,
    required this.timestamp,
  });

  factory SyncClipboardItem.fromJson(Map<String, dynamic> json) =>
      _$SyncClipboardItemFromJson(json);
  Map<String, dynamic> toJson() => _$SyncClipboardItemToJson(this);
}

// 批量同步响应
@JsonSerializable()
class BatchSyncResponse {
  final List<ServerClipboardItem> synced;
  final List<Map<String, dynamic>>? failed;
  final int total;

  const BatchSyncResponse({
    required this.synced,
    this.failed,
    required this.total,
  });

  factory BatchSyncResponse.fromJson(Map<String, dynamic> json) =>
      _$BatchSyncResponseFromJson(json);
  Map<String, dynamic> toJson() => _$BatchSyncResponseToJson(this);
}

// 统计信息
@JsonSerializable()
class ClipboardStatistics {
  @JsonKey(name: 'total_items')
  final int totalItems;
  @JsonKey(name: 'synced_items')
  final int syncedItems;
  @JsonKey(name: 'unsynced_items')
  final int unsyncedItems;
  @JsonKey(name: 'total_content_size')
  final int totalContentSize;
  @JsonKey(name: 'type_distribution')
  final Map<String, int> typeDistribution;
  @JsonKey(name: 'recent_activity')
  final List<ActivityData> recentActivity;

  const ClipboardStatistics({
    required this.totalItems,
    required this.syncedItems,
    required this.unsyncedItems,
    required this.totalContentSize,
    required this.typeDistribution,
    required this.recentActivity,
  });

  factory ClipboardStatistics.fromJson(Map<String, dynamic> json) =>
      _$ClipboardStatisticsFromJson(json);
  Map<String, dynamic> toJson() => _$ClipboardStatisticsToJson(this);
}

// 活动数据
@JsonSerializable()
class ActivityData {
  final String date;
  final int count;

  const ActivityData({
    required this.date,
    required this.count,
  });

  factory ActivityData.fromJson(Map<String, dynamic> json) =>
      _$ActivityDataFromJson(json);
  Map<String, dynamic> toJson() => _$ActivityDataToJson(this);
}

// 系统健康状态
@JsonSerializable()
class SystemHealth {
  final String database;
  final String service;
  final String status;
  final DateTime timestamp;
  final String uptime;
  final String version;

  const SystemHealth({
    required this.database,
    required this.service,
    required this.status,
    required this.timestamp,
    required this.uptime,
    required this.version,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) =>
      _$SystemHealthFromJson(json);
  Map<String, dynamic> toJson() => _$SystemHealthToJson(this);
}
