import 'package:flutter/foundation.dart';

@immutable
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String title;
  final String description;
  final String issueTag;
  final List<String> imageUrls;
  final String? cattleTag;
  final int likesCount;
  final int commentsCount;
  final bool resolved;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.title,
    required this.description,
    required this.issueTag,
    required this.imageUrls,
    this.cattleTag,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.resolved = false,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    List<String> parseImages(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    DateTime parseDate(dynamic raw) {
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return CommunityPost(
      id: json['id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Farmer',
      authorRole: json['author_role'] as String? ?? 'farmer',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      issueTag: json['issue_tag'] as String? ?? 'General Health',
      imageUrls: parseImages(json['image_urls']),
      cattleTag: json['cattle_tag'] as String?,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      resolved: json['resolved'] == true || json['resolved'] == 1,
      createdAt: parseDate(json['created_at']),
    );
  }
}

@immutable
class CommunityComment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final bool isVerifiedVet;
  final String? vetQualification;
  final String? vetClinic;
  final String comment;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    this.isVerifiedVet = false,
    this.vetQualification,
    this.vetClinic,
    required this.comment,
    required this.createdAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw) {
      if (raw is String) {
        return DateTime.tryParse(raw) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return CommunityComment(
      id: json['id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Member',
      authorRole: json['author_role'] as String? ?? 'farmer',
      isVerifiedVet: json['is_verified_vet'] == true || json['is_verified_vet'] == 1,
      vetQualification: json['vet_qualification'] as String?,
      vetClinic: json['vet_clinic'] as String?,
      comment: json['comment'] as String? ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}
