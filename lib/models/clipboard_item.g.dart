// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clipboard_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClipboardItemAdapter extends TypeAdapter<ClipboardItem> {
  @override
  final int typeId = 0;

  @override
  ClipboardItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClipboardItem(
      id: fields[0] as String,
      content: fields[1] as String,
      timestamp: fields[2] as DateTime,
      isSynced: fields[3] as bool,
      syncedAt: fields[4] as String?,
      type: fields[5] as ClipboardType,
      serverId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ClipboardItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.isSynced)
      ..writeByte(4)
      ..write(obj.syncedAt)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.serverId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ClipboardTypeAdapter extends TypeAdapter<ClipboardType> {
  @override
  final int typeId = 1;

  @override
  ClipboardType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ClipboardType.text;
      case 1:
        return ClipboardType.image;
      case 2:
        return ClipboardType.file;
      default:
        return ClipboardType.text;
    }
  }

  @override
  void write(BinaryWriter writer, ClipboardType obj) {
    switch (obj) {
      case ClipboardType.text:
        writer.writeByte(0);
        break;
      case ClipboardType.image:
        writer.writeByte(1);
        break;
      case ClipboardType.file:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
