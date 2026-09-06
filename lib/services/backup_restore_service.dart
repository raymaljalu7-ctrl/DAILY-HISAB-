import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class BackupRestoreService {
  BackupRestoreService._();

  static final BackupRestoreService instance =
      BackupRestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _rootCollection = 'sharedData';
  static const String _rootDocument = 'dailyHisab';

  static const List<String> businessCollections = [
    'sales',
    'transactions',
    'production',
    'productionExpenses',
    'salary',
    'capital',
    'commissions',
    'products',
    'retailShops',
    'parties',
    'workers',
  ];

  CollectionReference<Map<String, dynamic>> _collection(
    String name,
  ) {
    return _db
        .collection(_rootCollection)
        .doc(_rootDocument)
        .collection(name);
  }

  Future<Map<String, dynamic>> createBackup() async {
    final Map<String, dynamic> backup = {
      'backupVersion': 1,
      'app': 'Daily Hisab',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'collections': <String, dynamic>{},
    };

    final collections =
        backup['collections'] as Map<String, dynamic>;

    for (final collectionName in businessCollections) {
      final snapshot = await _collection(collectionName).get();

      collections[collectionName] = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'data': _encodeValue(doc.data()),
        };
      }).toList();
    }

    return backup;
  }

  Future<String> createBackupJson() async {
    final backup = await createBackup();

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(backup);
  }

  Future<void> shareBackup() async {
    final json = await createBackupJson();

    final timestamp = DateTime.now()
        .toLocal()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    final fileName = 'daily_hisab_backup_$timestamp.json';

    await SharePlus.instance.share(
      ShareParams(
        text: json,
        subject: fileName,
      ),
    );
  }

  Future<int> restoreFromFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (file == null) {
      return 0;
    }

    final bytes = await file.readAsBytes();
    final jsonText = utf8.decode(bytes);
    final decoded = jsonDecode(jsonText);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid Daily Hisab backup file.');
    }

    if (decoded['app'] != 'Daily Hisab') {
      throw Exception('This is not a Daily Hisab backup file.');
    }

    final collections = decoded['collections'];

    if (collections is! Map<String, dynamic>) {
      throw Exception('Backup file contains no business data.');
    }

    int restoredRecords = 0;

    for (final collectionName in businessCollections) {
      final records = collections[collectionName];

      if (records is! List) {
        continue;
      }

      for (final record in records) {
        if (record is! Map) {
          continue;
        }

        final id = record['id']?.toString();
        final rawData = record['data'];

        if (id == null || rawData is! Map) {
          continue;
        }

        final data = _decodeMap(
          Map<String, dynamic>.from(rawData),
        );

        await _collection(collectionName)
            .doc(id)
            .set(data);

        restoredRecords++;
      }
    }

    return restoredRecords;
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {
        '__type': 'timestamp',
        'value': value.toDate().toUtc().toIso8601String(),
      };
    }

    if (value is DateTime) {
      return {
        '__type': 'datetime',
        'value': value.toUtc().toIso8601String(),
      };
    }

    if (value is GeoPoint) {
      return {
        '__type': 'geopoint',
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }

    if (value is DocumentReference) {
      return {
        '__type': 'documentReference',
        'path': value.path,
      };
    }

    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(
          key.toString(),
          _encodeValue(value),
        ),
      );
    }

    if (value is List) {
      return value.map(_encodeValue).toList();
    }

    if (value is Uint8List) {
      return {
        '__type': 'bytes',
        'value': base64Encode(value),
      };
    }

    return value;
  }

  Map<String, dynamic> _decodeMap(
    Map<String, dynamic> map,
  ) {
    return map.map(
      (key, value) => MapEntry(
        key,
        _decodeValue(value),
      ),
    );
  }

  dynamic _decodeValue(dynamic value) {
    if (value is Map) {
      final type = value['__type'];

      if (type == 'timestamp' || type == 'datetime') {
        return Timestamp.fromDate(
          DateTime.parse(value['value'].toString()).toUtc(),
        );
      }

      if (type == 'geopoint') {
        return GeoPoint(
          (value['latitude'] as num).toDouble(),
          (value['longitude'] as num).toDouble(),
        );
      }

      if (type == 'documentReference') {
        return _db.doc(value['path'].toString());
      }

      if (type == 'bytes') {
        return base64Decode(value['value'].toString());
      }

      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _decodeValue(nestedValue),
        ),
      );
    }

    if (value is List) {
      return value.map(_decodeValue).toList();
    }

    return value;
  }
}
