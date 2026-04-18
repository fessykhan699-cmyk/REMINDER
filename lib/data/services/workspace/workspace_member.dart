import 'package:cloud_firestore/cloud_firestore.dart';

class WorkspaceMember {
  const WorkspaceMember({
    required this.memberId,
    required this.memberEmail,
    required this.joinedAt,
    required this.status,
  });

  final String memberId;
  final String memberEmail;
  final DateTime joinedAt;
  final String status;

  factory WorkspaceMember.fromMap(Map<String, dynamic> map) {
    final joinedRaw = map['joinedAt'];
    final joinedAt = joinedRaw is Timestamp
        ? joinedRaw.toDate()
        : (joinedRaw is DateTime ? joinedRaw : DateTime.now());

    return WorkspaceMember(
      memberId: (map['memberId'] as String?) ?? '',
      memberEmail: (map['memberEmail'] as String?) ?? '',
      joinedAt: joinedAt,
      status: (map['status'] as String?) ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'memberId': memberId,
      'memberEmail': memberEmail,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'status': status,
    };
  }
}
