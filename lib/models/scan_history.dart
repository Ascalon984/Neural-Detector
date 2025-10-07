class ScanHistory {
  final String id;
  final String fileName;
  final String date; // formatted
  final int aiDetection;
  final int humanWritten;
  final String status;
  final String fileSize;
  final String source; // 'camera'|'upload'|'editor'|'history' etc.

  ScanHistory({
    required this.id,
    required this.fileName,
    required this.date,
    required this.aiDetection,
    required this.humanWritten,
    required this.status,
    required this.fileSize,
    this.source = 'history',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'date': date,
        'aiDetection': aiDetection,
        'humanWritten': humanWritten,
        'status': status,
        'fileSize': fileSize,
        'source': source,
      };

  factory ScanHistory.fromJson(Map<String, dynamic> json) => ScanHistory(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        date: json['date'] as String,
        aiDetection: (json['aiDetection'] as num).toInt(),
        humanWritten: (json['humanWritten'] as num).toInt(),
        status: json['status'] as String,
        fileSize: json['fileSize'] as String,
        source: (json['source'] as String?) ?? 'history',
      );
}
