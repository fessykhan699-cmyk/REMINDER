import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'workspace_exceptions.dart';
import 'workspace_member.dart';

class WorkspaceService {
  WorkspaceService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _membersCollection(String ownerId) {
    return _firestore
        .collection('workspaces')
        .doc(ownerId)
        .collection('members');
  }

  Future<void> createWorkspace(String ownerId) async {
    try {
      await _firestore
          .collection('workspaces')
          .doc(ownerId)
          .set(<String, dynamic>{
            'ownerId': ownerId,
            'createdAt': FieldValue.serverTimestamp(),
            'memberCount': 0,
          }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('[WorkspaceService] createWorkspace failed: $e\n$st');
    }
  }

  Future<void> inviteMember(String ownerId, String memberEmail) async {
    try {
      await createWorkspace(ownerId);

      final workspaceRef = _firestore.collection('workspaces').doc(ownerId);
      final workspaceSnapshot = await workspaceRef.get();
      final workspaceData = workspaceSnapshot.data() ?? <String, dynamic>{};
      final memberCount = (workspaceData['memberCount'] as num?)?.toInt() ?? 0;
      if (memberCount >= 2) {
        throw const WorkspaceLimitException();
      }

      final normalizedEmail = memberEmail.trim().toLowerCase();
      final userQuery = await _firestore
          .collection('userProfiles')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) {
        throw const MemberNotFoundException();
      }

      final memberDoc = userQuery.docs.first;
      final memberId = memberDoc.id;
      if (memberId == ownerId) {
        throw const MemberNotFoundException(
          'Owner cannot be invited as a member',
        );
      }

      final now = FieldValue.serverTimestamp();
      await _membersCollection(ownerId).doc(memberId).set(<String, dynamic>{
        'memberId': memberId,
        'memberEmail': normalizedEmail,
        'joinedAt': now,
        'status': 'active',
      }, SetOptions(merge: true));

      await _firestore.collection('workspaceMemberships').doc(memberId).set(
        <String, dynamic>{'ownerId': ownerId, 'joinedAt': now},
        SetOptions(merge: true),
      );

      await workspaceRef.set(<String, dynamic>{
        'memberCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } on WorkspaceLimitException {
      rethrow;
    } on MemberNotFoundException {
      rethrow;
    } catch (e, st) {
      debugPrint('[WorkspaceService] inviteMember failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> removeMember(String ownerId, String memberId) async {
    try {
      await _membersCollection(ownerId).doc(memberId).delete();
      await _firestore
          .collection('workspaceMemberships')
          .doc(memberId)
          .delete();
      await _firestore.collection('workspaces').doc(ownerId).set(
        <String, dynamic>{'memberCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('[WorkspaceService] removeMember failed: $e\n$st');
    }
  }

  Future<List<WorkspaceMember>> getMembers(String ownerId) async {
    try {
      final snapshot = await _membersCollection(ownerId).get();
      return snapshot.docs
          .map((doc) => WorkspaceMember.fromMap(doc.data()))
          .where((member) => member.memberId.isNotEmpty)
          .toList(growable: false);
    } catch (e, st) {
      debugPrint('[WorkspaceService] getMembers failed: $e\n$st');
      return const <WorkspaceMember>[];
    }
  }

  Future<String?> resolveWorkspaceOwner(String userId) async {
    try {
      final membership = await _firestore
          .collection('workspaceMemberships')
          .doc(userId)
          .get();
      if (!membership.exists) {
        return null;
      }
      final data = membership.data();
      return data?['ownerId'] as String?;
    } catch (e, st) {
      debugPrint('[WorkspaceService] resolveWorkspaceOwner failed: $e\n$st');
      return null;
    }
  }

  Future<String?> getOwnerEmail(String ownerId) async {
    try {
      final query = await _firestore
          .collection('userProfiles')
          .where('userId', isEqualTo: ownerId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data()['email'] as String?;
      }

      final direct = await _firestore
          .collection('userProfiles')
          .doc(ownerId)
          .get();
      if (direct.exists) {
        return direct.data()?['email'] as String?;
      }
    } catch (e, st) {
      debugPrint('[WorkspaceService] getOwnerEmail failed: $e\n$st');
    }
    return null;
  }
}
