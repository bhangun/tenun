import 'dart:convert';
import 'dart:typed_data';

class ChartZipStoreFile {
  const ChartZipStoreFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class ChartZipStoreWriter {
  const ChartZipStoreWriter._();

  static const int _utf8FilenameFlag = 0x0800;
  static const int _maxClassicZipEntries = 0xffff;
  static const int _maxUint32 = 0xffffffff;

  /// Write UTF-8 text files to a dependency-free ZIP archive.
  ///
  /// Entries are stored without compression. That keeps the implementation
  /// portable across Flutter targets and is sufficient for bundling exports.
  static Uint8List writeText(Map<String, String> files) {
    return writeFiles(
      files.entries.map(
        (entry) => ChartZipStoreFile(
          name: entry.key,
          bytes: Uint8List.fromList(utf8.encode(entry.value)),
        ),
      ),
    );
  }

  /// Write byte files to a dependency-free ZIP archive.
  static Uint8List writeBytes(Map<String, Uint8List> files) {
    return writeFiles(
      files.entries.map(
        (entry) => ChartZipStoreFile(name: entry.key, bytes: entry.value),
      ),
    );
  }

  /// Write files to a dependency-free ZIP archive.
  ///
  /// Duplicate or unsafe entry names are normalized before writing. The writer
  /// intentionally supports classic ZIP only; very large ZIP64 archives should
  /// be handled by a platform/package implementation instead.
  static Uint8List writeFiles(Iterable<ChartZipStoreFile> files) {
    final sourceFiles = files.toList(growable: false);
    if (sourceFiles.length > _maxClassicZipEntries) {
      throw ArgumentError.value(
        sourceFiles.length,
        'files',
        'Classic ZIP supports at most $_maxClassicZipEntries entries.',
      );
    }

    final output = BytesBuilder(copy: false);
    final entries = <_ChartZipStoreEntry>[];
    final usedEntryNames = <String>{};
    final entryNameCounts = <String, int>{};

    for (var index = 0; index < sourceFiles.length; index++) {
      final source = sourceFiles[index];
      final entryName = _uniqueEntryName(
        _sanitizeEntryName(source.name, index + 1),
        usedEntryNames,
        entryNameCounts,
      );
      final nameBytes = utf8.encode(entryName);
      if (nameBytes.length > _maxClassicZipEntries) {
        throw ArgumentError.value(
          entryName,
          'files',
          'ZIP entry names must be shorter than $_maxClassicZipEntries bytes.',
        );
      }

      final data = Uint8List.fromList(source.bytes);
      _validateUint32(data.length, 'file size');
      _validateUint32(output.length, 'local header offset');
      final offset = output.length;
      final crc = _crc32(data);
      entries.add(
        _ChartZipStoreEntry(
          nameBytes: nameBytes,
          data: data,
          crc32: crc,
          localHeaderOffset: offset,
        ),
      );

      _writeUint32(output, 0x04034b50);
      _writeUint16(output, 20);
      _writeUint16(output, _utf8FilenameFlag);
      _writeUint16(output, 0);
      _writeUint16(output, 0);
      _writeUint16(output, 0);
      _writeUint32(output, crc);
      _writeUint32(output, data.length);
      _writeUint32(output, data.length);
      _writeUint16(output, nameBytes.length);
      _writeUint16(output, 0);
      output.add(nameBytes);
      output.add(data);
    }

    _validateUint32(output.length, 'central directory offset');
    final centralDirectoryOffset = output.length;
    for (final entry in entries) {
      _writeUint32(output, 0x02014b50);
      _writeUint16(output, 20);
      _writeUint16(output, 20);
      _writeUint16(output, _utf8FilenameFlag);
      _writeUint16(output, 0);
      _writeUint16(output, 0);
      _writeUint16(output, 0);
      _writeUint32(output, entry.crc32);
      _writeUint32(output, entry.data.length);
      _writeUint32(output, entry.data.length);
      _writeUint16(output, entry.nameBytes.length);
      _writeUint16(output, 0);
      _writeUint16(output, 0);
      _writeUint16(output, 0);
      _writeUint16(output, 0);
      _writeUint32(output, 0);
      _writeUint32(output, entry.localHeaderOffset);
      output.add(entry.nameBytes);
    }

    final centralDirectorySize = output.length - centralDirectoryOffset;
    _validateUint32(centralDirectorySize, 'central directory size');
    _writeUint32(output, 0x06054b50);
    _writeUint16(output, 0);
    _writeUint16(output, 0);
    _writeUint16(output, entries.length);
    _writeUint16(output, entries.length);
    _writeUint32(output, centralDirectorySize);
    _writeUint32(output, centralDirectoryOffset);
    _writeUint16(output, 0);

    return output.toBytes();
  }

  static String _sanitizeEntryName(String name, int index) {
    final normalized = name.replaceAll('\\', '/');
    final parts = <String>[];
    for (final rawPart in normalized.split('/')) {
      final trimmed = rawPart.trim();
      if (trimmed.isEmpty || trimmed == '.') continue;
      if (trimmed == '..') continue;

      var part = trimmed
          .replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"|?*]+'), '_')
          .trim();
      part = part.replaceAll(RegExp(r'\s+'), ' ');
      part = part.replaceAll(RegExp(r'_+'), '_');
      part = part.replaceAll(RegExp(r'[\s_]+$'), '');
      if (part.isEmpty || part == '.' || part == '..') part = 'file';
      if (_reservedDeviceName.hasMatch(part)) part = '${part}_export';
      parts.add(part);
    }

    if (parts.isEmpty) return 'file_$index';
    return parts.join('/');
  }

  static String _uniqueEntryName(
    String name,
    Set<String> usedEntryNames,
    Map<String, int> entryNameCounts,
  ) {
    var candidate = name;
    var count = entryNameCounts[name] ?? 1;
    while (usedEntryNames.contains(candidate)) {
      count++;
      candidate = _appendSuffix(name, count);
    }
    entryNameCounts[name] = count;
    usedEntryNames.add(candidate);
    return candidate;
  }

  static String _appendSuffix(String name, int count) {
    final slashIndex = name.lastIndexOf('/');
    final folder = slashIndex >= 0 ? name.substring(0, slashIndex + 1) : '';
    final file = slashIndex >= 0 ? name.substring(slashIndex + 1) : name;
    final dotIndex = file.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == file.length - 1) {
      return '$folder${file}_$count';
    }

    final stem = file.substring(0, dotIndex).replaceAll(RegExp(r'[\s_]+$'), '');
    final safeStem = stem.isEmpty ? file.substring(0, dotIndex) : stem;
    return '$folder${safeStem}_$count${file.substring(dotIndex)}';
  }

  static void _writeUint16(BytesBuilder output, int value) {
    final bytes = ByteData(2)..setUint16(0, value, Endian.little);
    output.add(bytes.buffer.asUint8List());
  }

  static void _writeUint32(BytesBuilder output, int value) {
    final bytes = ByteData(4)..setUint32(0, value, Endian.little);
    output.add(bytes.buffer.asUint8List());
  }

  static void _validateUint32(int value, String fieldName) {
    if (value < 0 || value > _maxUint32) {
      throw ArgumentError.value(
        value,
        fieldName,
        'Classic ZIP cannot encode values larger than $_maxUint32.',
      );
    }
  }

  static int _crc32(Uint8List data) {
    var crc = 0xffffffff;
    for (final byte in data) {
      crc = _crc32Table[(crc ^ byte) & 0xff] ^ (crc >> 8);
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  static final RegExp _reservedDeviceName = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$',
    caseSensitive: false,
  );

  static final List<int> _crc32Table = List<int>.generate(256, (index) {
    var value = index;
    for (var bit = 0; bit < 8; bit++) {
      value = (value & 1) == 1 ? 0xedb88320 ^ (value >> 1) : value >> 1;
    }
    return value;
  }, growable: false);
}

class _ChartZipStoreEntry {
  const _ChartZipStoreEntry({
    required this.nameBytes,
    required this.data,
    required this.crc32,
    required this.localHeaderOffset,
  });

  final List<int> nameBytes;
  final Uint8List data;
  final int crc32;
  final int localHeaderOffset;
}
