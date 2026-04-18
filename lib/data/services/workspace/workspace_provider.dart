import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/auth/presentation/controllers/auth_controller.dart';
import 'workspace_member.dart';
import 'workspace_service.dart';

const workspaceOwnerIdStorageKey = 'workspace_owner_id';

final workspaceServiceProvider = Provider<WorkspaceService>(
  (ref) => WorkspaceService(),
);

final workspaceOwnerIdStateProvider = StateProvider<String?>((ref) => null);

final workspaceOwnerIdProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(authControllerProvider).session?.userId;
  if (userId == null) {
    return null;
  }
  return ref.read(workspaceServiceProvider).resolveWorkspaceOwner(userId);
});

final activeWorkspaceOwnerIdProvider = Provider<String?>((ref) {
  final currentUserId = ref.watch(authControllerProvider).session?.userId;
  if (currentUserId == null) {
    return null;
  }
  final storedOwnerId = ref.watch(workspaceOwnerIdStateProvider);
  return storedOwnerId ?? currentUserId;
});

final workspaceMembersProvider =
    AsyncNotifierProvider<WorkspaceMembersNotifier, List<WorkspaceMember>>(
      WorkspaceMembersNotifier.new,
    );

class WorkspaceMembersNotifier extends AsyncNotifier<List<WorkspaceMember>> {
  @override
  Future<List<WorkspaceMember>> build() async {
    final ownerId = ref.watch(activeWorkspaceOwnerIdProvider);
    if (ownerId == null) {
      return const <WorkspaceMember>[];
    }
    return ref.read(workspaceServiceProvider).getMembers(ownerId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final ownerId = ref.read(activeWorkspaceOwnerIdProvider);
      if (ownerId == null) {
        return const <WorkspaceMember>[];
      }
      return ref.read(workspaceServiceProvider).getMembers(ownerId);
    });
  }
}

class WorkspaceOwnerStorage {
  const WorkspaceOwnerStorage._();

  static Future<void> save(String ownerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(workspaceOwnerIdStorageKey, ownerId);
    } catch (e, st) {
      debugPrint('[WorkspaceOwnerStorage] save failed: $e\n$st');
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(workspaceOwnerIdStorageKey);
    } catch (e, st) {
      debugPrint('[WorkspaceOwnerStorage] clear failed: $e\n$st');
    }
  }

  static Future<String?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(workspaceOwnerIdStorageKey);
    } catch (e, st) {
      debugPrint('[WorkspaceOwnerStorage] load failed: $e\n$st');
      return null;
    }
  }
}
