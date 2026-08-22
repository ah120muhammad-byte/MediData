class DownloadedFile {
  final String id;
  final String lectureId;
  final String title;
  final String fileType;
  final String fileUrl;
  final String localPath;
  final DateTime downloadedAt;

  const DownloadedFile({
    required this.id,
    required this.lectureId,
    required this.title,
    required this.fileType,
    required this.fileUrl,
    required this.localPath,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lectureId': lectureId,
      'title': title,
      'fileType': fileType,
      'fileUrl': fileUrl,
      'localPath': localPath,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  factory DownloadedFile.fromJson(Map<String, dynamic> json) {
    return DownloadedFile(
      id: json['id']?.toString() ?? '',
      lectureId: json['lectureId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      fileType: json['fileType']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? '',
      localPath: json['localPath']?.toString() ?? '',
      downloadedAt: DateTime.tryParse(
            json['downloadedAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}