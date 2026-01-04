import 'package:isar/isar.dart';

part 'feedDraftDB_isar.g.dart';

@collection
class FeedDraftDBISAR {
  @Id()
  int id = 0;

  @Index(unique: true)
  String author; // Current user's pubkey (unique index, ensures one draft per user)

  String content; // Text content
  List<String>? imageUrls; // Uploaded image URLs
  List<String>? videoUrls; // Uploaded video URLs
  String? draftCueUserMapJson; // JSON serialization of @user info
  int updatedAt; // Last update timestamp

  FeedDraftDBISAR({
    this.author = '',
    this.content = '',
    this.imageUrls,
    this.videoUrls,
    this.draftCueUserMapJson,
    this.updatedAt = 0,
  });

  static FeedDraftDBISAR fromMap(Map<String, dynamic> map) {
    return FeedDraftDBISAR(
      author: map['author']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      imageUrls: map['imageUrls'] != null
          ? List<String>.from(map['imageUrls'])
          : null,
      videoUrls: map['videoUrls'] != null
          ? List<String>.from(map['videoUrls'])
          : null,
      draftCueUserMapJson: map['draftCueUserMapJson']?.toString(),
      updatedAt: map['updatedAt'] ?? 0,
    );
  }
}
