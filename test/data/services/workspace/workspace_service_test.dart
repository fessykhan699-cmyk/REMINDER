@Tags(['native'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder/data/services/workspace/workspace_exceptions.dart';
import 'package:reminder/data/services/workspace/workspace_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late WorkspaceService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = WorkspaceService(firestore: firestore);
  });

  test('createWorkspace writes workspace document with memberCount 0', () async {
    await service.createWorkspace('owner-1');

    final snapshot = await firestore.collection('workspaces').doc('owner-1').get();
    expect(snapshot.exists, isTrue);
    expect(snapshot.data()?['ownerId'], 'owner-1');
    expect(snapshot.data()?['memberCount'], 0);
  });

  test('inviteMember writes member and membership documents', () async {
    await firestore.collection('userProfiles').doc('member-1').set(<String, dynamic>{
      'email': 'member@test.com',
    });

    await service.inviteMember('owner-1', 'member@test.com');

    final memberSnapshot = await firestore
        .collection('workspaces')
        .doc('owner-1')
        .collection('members')
        .doc('member-1')
        .get();
    final membershipSnapshot = await firestore
        .collection('workspaceMemberships')
        .doc('member-1')
        .get();

    expect(memberSnapshot.exists, isTrue);
    expect(memberSnapshot.data()?['memberEmail'], 'member@test.com');
    expect(membershipSnapshot.exists, isTrue);
    expect(membershipSnapshot.data()?['ownerId'], 'owner-1');
  });

  test('inviteMember throws WorkspaceLimitException when memberCount is 2', () async {
    final noCreateService = _NoCreateWorkspaceService(firestore: firestore);
    await firestore.collection('workspaces').doc('owner-1').set(
      <String, dynamic>{'ownerId': 'owner-1', 'memberCount': 2},
    );
    await firestore.collection('userProfiles').doc('member-1').set(<String, dynamic>{
      'email': 'member@test.com',
    });

    expect(
      () => noCreateService.inviteMember('owner-1', 'member@test.com'),
      throwsA(isA<WorkspaceLimitException>()),
    );
  });

  test('removeMember deletes member and membership documents', () async {
    await firestore.collection('workspaces').doc('owner-1').set(
      <String, dynamic>{'ownerId': 'owner-1', 'memberCount': 1},
    );
    await firestore
        .collection('workspaces')
        .doc('owner-1')
        .collection('members')
        .doc('member-1')
        .set(<String, dynamic>{'memberId': 'member-1'});
    await firestore.collection('workspaceMemberships').doc('member-1').set(
      <String, dynamic>{'ownerId': 'owner-1'},
    );

    await service.removeMember('owner-1', 'member-1');

    final memberSnapshot = await firestore
        .collection('workspaces')
        .doc('owner-1')
        .collection('members')
        .doc('member-1')
        .get();
    final membershipSnapshot = await firestore
        .collection('workspaceMemberships')
        .doc('member-1')
        .get();

    expect(memberSnapshot.exists, isFalse);
    expect(membershipSnapshot.exists, isFalse);
  });

  test('resolveWorkspaceOwner returns ownerId when membership exists', () async {
    await firestore.collection('workspaceMemberships').doc('member-1').set(
      <String, dynamic>{'ownerId': 'owner-1'},
    );

    final ownerId = await service.resolveWorkspaceOwner('member-1');
    expect(ownerId, 'owner-1');
  });

  test('resolveWorkspaceOwner returns null when membership does not exist', () async {
    final ownerId = await service.resolveWorkspaceOwner('unknown');
    expect(ownerId, isNull);
  });
}

class _NoCreateWorkspaceService extends WorkspaceService {
  _NoCreateWorkspaceService({required super.firestore});

  @override
  Future<void> createWorkspace(String ownerId) async {}
}
