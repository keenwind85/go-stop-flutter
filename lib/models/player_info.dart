/// 플레이어 기본 정보
class PlayerInfo {
  final String uid;
  final String displayName;

  const PlayerInfo({
    required this.uid,
    required this.displayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
    };
  }

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String? ?? 'Unknown',
    );
  }
}
