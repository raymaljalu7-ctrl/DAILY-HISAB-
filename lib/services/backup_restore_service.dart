import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class BackupRestoreService {
  BackupRestoreService._();
  static final instance = BackupRestoreService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _rootCollection = 'sharedData';
  static const String _rootDocument = 'dailyHisab';
  static const List<String> businessCollections = [
    'sales','transactions','production','stockTransfers','stockOtherReceived',
    'productionExpenses','salary','capital','commissions','products',
    'retailShops','parties','workers','openingBalances',
  ];
  CollectionReference<Map<String,dynamic>> _collection(String name) => _db.collection(_rootCollection).doc(_rootDocument).collection(name);

  Future<Map<String,dynamic>> createBackup() async {
    final backup = <String,dynamic>{'backupVersion':2,'app':'Daily Hisab','createdAt':DateTime.now().toUtc().toIso8601String(),'collections':<String,dynamic>{}};
    final collections = backup['collections'] as Map<String,dynamic>;
    for (final name in businessCollections) {
      final snapshot = await _collection(name).get();
      collections[name] = snapshot.docs.map((doc)=>{'id':doc.id,'data':_encodeValue(doc.data())}).toList();
    }
    return backup;
  }

  Future<String> createBackupJson() async => const JsonEncoder.withIndent('  ').convert(await createBackup());

  Future<void> shareBackup() async {
    final json = await createBackupJson();
    final timestamp = DateTime.now().toLocal().toIso8601String().replaceAll(':','-').replaceAll('.','-');
    await SharePlus.instance.share(ShareParams(text:json,subject:'daily_hisab_backup_$timestamp.json'));
  }

  Future<int> restoreFromFile() async {
    final file = await FilePicker.pickFile(type:FileType.custom,allowedExtensions:['json']);
    if (file == null) return 0;
    final decoded = jsonDecode(utf8.decode(await file.readAsBytes()));
    if (decoded is! Map<String,dynamic> || decoded['app'] != 'Daily Hisab') throw Exception('Invalid Daily Hisab backup file.');
    final collections = decoded['collections'];
    if (collections is! Map<String,dynamic>) throw Exception('Backup file contains no business data.');
    int count = 0;
    for (final name in businessCollections) {
      final records = collections[name]; if (records is! List) continue;
      for (final record in records) {
        if (record is! Map) continue;
        final id = record['id']?.toString(); final raw = record['data'];
        if (id == null || raw is! Map) continue;
        await _collection(name).doc(id).set(_decodeMap(Map<String,dynamic>.from(raw))); count++;
      }
    }
    return count;
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) return {'__type':'timestamp','value':value.toDate().toUtc().toIso8601String()};
    if (value is DateTime) return {'__type':'datetime','value':value.toUtc().toIso8601String()};
    if (value is GeoPoint) return {'__type':'geopoint','latitude':value.latitude,'longitude':value.longitude};
    if (value is DocumentReference) return {'__type':'documentReference','path':value.path};
    if (value is Map) return value.map((k,v)=>MapEntry(k.toString(),_encodeValue(v)));
    if (value is List) return value.map(_encodeValue).toList();
    if (value is Uint8List) return {'__type':'bytes','value':base64Encode(value)};
    return value;
  }
  Map<String,dynamic> _decodeMap(Map<String,dynamic> map) => map.map((k,v)=>MapEntry(k,_decodeValue(v)));
  dynamic _decodeValue(dynamic value) {
    if (value is Map) {
      final type=value['__type'];
      if (type=='timestamp'||type=='datetime') return Timestamp.fromDate(DateTime.parse(value['value'].toString()).toUtc());
      if (type=='geopoint') return GeoPoint((value['latitude'] as num).toDouble(),(value['longitude'] as num).toDouble());
      if (type=='documentReference') return _db.doc(value['path'].toString());
      if (type=='bytes') return base64Decode(value['value'].toString());
      return value.map((k,v)=>MapEntry(k.toString(),_decodeValue(v)));
    }
    if (value is List) return value.map(_decodeValue).toList();
    return value;
  }
}
