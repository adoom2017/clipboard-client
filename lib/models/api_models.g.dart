// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLogin: json['last_login'] == null
          ? null
          : DateTime.parse(json['last_login'] as String),
      totalItems: (json['total_items'] as num?)?.toInt(),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'created_at': instance.createdAt.toIso8601String(),
      'last_login': instance.lastLogin?.toIso8601String(),
      'total_items': instance.totalItems,
    };

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
      token: json['token'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'token': instance.token,
      'user': instance.user,
    };

ServerClipboardItem _$ServerClipboardItemFromJson(Map<String, dynamic> json) =>
    ServerClipboardItem(
      id: json['id'] as String,
      content: json['content'] as String,
      type: json['type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ServerClipboardItemToJson(
        ServerClipboardItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'type': instance.type,
      'timestamp': instance.timestamp.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

ClipboardListResponse _$ClipboardListResponseFromJson(
        Map<String, dynamic> json) =>
    ClipboardListResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => ServerClipboardItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      totalPages: (json['total_pages'] as num).toInt(),
      hasNext: json['has_next'] as bool,
      hasPrev: json['has_prev'] as bool,
    );

Map<String, dynamic> _$ClipboardListResponseToJson(
        ClipboardListResponse instance) =>
    <String, dynamic>{
      'items': instance.items,
      'total': instance.total,
      'page': instance.page,
      'page_size': instance.pageSize,
      'total_pages': instance.totalPages,
      'has_next': instance.hasNext,
      'has_prev': instance.hasPrev,
    };

BatchSyncRequest _$BatchSyncRequestFromJson(Map<String, dynamic> json) =>
    BatchSyncRequest(
      deviceId: json['device_id'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => SyncClipboardItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BatchSyncRequestToJson(BatchSyncRequest instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

SyncClipboardItem _$SyncClipboardItemFromJson(Map<String, dynamic> json) =>
    SyncClipboardItem(
      type: json['type'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$SyncClipboardItemToJson(SyncClipboardItem instance) =>
    <String, dynamic>{
      'type': instance.type,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
    };

BatchSyncResponse _$BatchSyncResponseFromJson(Map<String, dynamic> json) =>
    BatchSyncResponse(
      synced: (json['synced'] as List<dynamic>)
          .map((e) => ServerClipboardItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      failed: (json['failed'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      total: (json['total'] as num).toInt(),
    );

Map<String, dynamic> _$BatchSyncResponseToJson(BatchSyncResponse instance) =>
    <String, dynamic>{
      'synced': instance.synced,
      'failed': instance.failed,
      'total': instance.total,
    };

ClipboardStatistics _$ClipboardStatisticsFromJson(Map<String, dynamic> json) =>
    ClipboardStatistics(
      totalItems: (json['total_items'] as num).toInt(),
      syncedItems: (json['synced_items'] as num).toInt(),
      unsyncedItems: (json['unsynced_items'] as num).toInt(),
      totalContentSize: (json['total_content_size'] as num).toInt(),
      typeDistribution: Map<String, int>.from(json['type_distribution'] as Map),
      recentActivity: (json['recent_activity'] as List<dynamic>?)
          ?.map((e) => ActivityData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ClipboardStatisticsToJson(
        ClipboardStatistics instance) =>
    <String, dynamic>{
      'total_items': instance.totalItems,
      'synced_items': instance.syncedItems,
      'unsynced_items': instance.unsyncedItems,
      'total_content_size': instance.totalContentSize,
      'type_distribution': instance.typeDistribution,
      'recent_activity': instance.recentActivity,
    };

ActivityData _$ActivityDataFromJson(Map<String, dynamic> json) => ActivityData(
      date: json['date'] as String,
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$ActivityDataToJson(ActivityData instance) =>
    <String, dynamic>{
      'date': instance.date,
      'count': instance.count,
    };

SystemHealth _$SystemHealthFromJson(Map<String, dynamic> json) => SystemHealth(
      database: json['database'] as String,
      service: json['service'] as String,
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      uptime: json['uptime'] as String,
      version: json['version'] as String,
    );

Map<String, dynamic> _$SystemHealthToJson(SystemHealth instance) =>
    <String, dynamic>{
      'database': instance.database,
      'service': instance.service,
      'status': instance.status,
      'timestamp': instance.timestamp.toIso8601String(),
      'uptime': instance.uptime,
      'version': instance.version,
    };
