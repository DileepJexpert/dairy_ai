import 'package:freezed_annotation/freezed_annotation.dart';

part 'cattle_model.freezed.dart';
part 'cattle_model.g.dart';

enum CattleStatus {
  @JsonValue('active')
  active,
  @JsonValue('dry')
  dry,
  @JsonValue('sold')
  sold,
  @JsonValue('deceased')
  deceased,
}

enum CattleSex {
  @JsonValue('female')
  female,
  @JsonValue('male')
  male,
}

@freezed
class Cattle with _$Cattle {
  const Cattle._();

  const factory Cattle({
    required String id,
    @JsonKey(name: 'farmer_id') required String farmerId,
    @JsonKey(name: 'tag_id') required String tagId,
    required String name,
    required String breed,
    required CattleSex sex,
    required DateTime dob,
    @JsonKey(name: 'photo_url') String? photoUrl,
    @Default(CattleStatus.active) CattleStatus status,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Cattle;

  factory Cattle.fromJson(Map<String, dynamic> json) =>
      _$CattleFromJson(json);

  String get age {
    final now = DateTime.now();
    final years = now.year - dob.year;
    final months = now.month - dob.month + (years * 12);
    final displayYears = months ~/ 12;
    final displayMonths = months % 12;
    if (displayYears > 0 && displayMonths > 0) {
      return '${displayYears}y ${displayMonths}m';
    } else if (displayYears > 0) {
      return '${displayYears}y';
    } else {
      return '${displayMonths}m';
    }
  }

  String get statusLabel {
    switch (status) {
      case CattleStatus.active:
        return 'Active';
      case CattleStatus.dry:
        return 'Dry';
      case CattleStatus.sold:
        return 'Sold';
      case CattleStatus.deceased:
        return 'Deceased';
    }
  }
}

@freezed
class CreateCattleRequest with _$CreateCattleRequest {
  const factory CreateCattleRequest({
    required String name,
    @JsonKey(name: 'tag_id') required String tagId,
    required String breed,
    required CattleSex sex,
    required DateTime dob,
    @JsonKey(name: 'photo_url') String? photoUrl,
  }) = _CreateCattleRequest;

  factory CreateCattleRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCattleRequestFromJson(json);
}

@freezed
class UpdateCattleRequest with _$UpdateCattleRequest {
  const factory UpdateCattleRequest({
    String? name,
    @JsonKey(name: 'tag_id') String? tagId,
    String? breed,
    CattleSex? sex,
    DateTime? dob,
    @JsonKey(name: 'photo_url') String? photoUrl,
    CattleStatus? status,
  }) = _UpdateCattleRequest;

  factory UpdateCattleRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateCattleRequestFromJson(json);
}
