import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../shared/components/app_scaffold.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../subscription/domain/entities/subscription_state.dart';
import '../../../subscription/presentation/controllers/subscription_controller.dart';
import '../../../../data/services/workspace/workspace_exceptions.dart';
import '../../../../data/services/workspace/workspace_member.dart';
import '../../../../data/services/workspace/workspace_provider.dart';

final _workspaceOwnerEmailProvider = FutureProvider<String?>((ref) async {
  final ownerId = ref.watch(activeWorkspaceOwnerIdProvider);
  if (ownerId == null) {
    return null;
  }
  return ref.read(workspaceServiceProvider).getOwnerEmail(ownerId);
});

class TeamMembersScreen extends ConsumerStatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  ConsumerState<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends ConsumerState<TeamMembersScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isInviting = false;
  bool _isLeaving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscription =
        ref.watch(subscriptionControllerProvider).valueOrNull ??
        const SubscriptionState.free();
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState.session?.userId;
    final ownerId = ref.watch(activeWorkspaceOwnerIdProvider);

    final isBusiness = subscription.isBusiness;
    final isOwner =
        currentUserId != null && ownerId != null && currentUserId == ownerId;

    return AppScaffold(
      appBar: AppBar(title: const Text('Team Members')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: !isBusiness
              ? _buildUpgradePrompt(context)
              : (!isOwner
                    ? _buildMemberView(context, ownerId)
                    : _buildOwnerView(context, ownerId)),
        ),
      ),
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team collaboration is a Business Plan feature.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Upgrade',
              icon: Icons.workspace_premium_outlined,
              onPressed: () => const UpgradeToProRoute().push(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberView(BuildContext context, String? ownerId) {
    final ownerEmailAsync = ref.watch(_workspaceOwnerEmailProvider);
    final ownerLabel = ownerEmailAsync.valueOrNull ?? ownerId ?? 'the owner';

    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are a member of $ownerLabel\'s workspace.',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: _isLeaving ? 'Leaving...' : 'Leave Workspace',
              icon: Icons.logout,
              onPressed: _isLeaving ? null : () => _leaveWorkspace(ownerId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerView(BuildContext context, String? ownerId) {
    if (ownerId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final membersAsync = ref.watch(workspaceMembersProvider);
    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Unable to load members right now.')),
      data: (members) => _buildMembersList(context, ownerId, members),
    );
  }

  Widget _buildMembersList(
    BuildContext context,
    String ownerId,
    List<WorkspaceMember> members,
  ) {
    final memberCount = members.length;
    final countText = '$memberCount of 2 seats used';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          countText,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: members.isEmpty
              ? const Center(child: Text('No team members yet.'))
              : ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.memberEmail,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Joined ${_formatDate(member.joinedAt)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _confirmAndRemoveMember(ownerId, member),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        if (memberCount < 2)
          PrimaryButton(
            label: _isInviting ? 'Inviting...' : 'Invite Member',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: _isInviting ? null : () => _showInviteDialog(ownerId),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _showInviteDialog(String ownerId) async {
    _emailController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Invite Member'),
          content: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _inviteMember(ownerId, _emailController.text.trim());
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _inviteMember(String ownerId, String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an email.')));
      return;
    }

    setState(() => _isInviting = true);
    try {
      await ref.read(workspaceServiceProvider).inviteMember(ownerId, email);
      await ref.read(workspaceMembersProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation sent.')));
    } on WorkspaceLimitException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have reached the 2 member limit.')),
      );
    } on MemberNotFoundException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No user found with that email. They must sign up for Invoice Flow first.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to invite member right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  Future<void> _confirmAndRemoveMember(
    String ownerId,
    WorkspaceMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Member'),
          content: Text('Remove ${member.memberEmail} from this workspace?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await ref
        .read(workspaceServiceProvider)
        .removeMember(ownerId, member.memberId);
    await ref.read(workspaceMembersProvider.notifier).refresh();
  }

  Future<void> _leaveWorkspace(String? ownerId) async {
    final currentUserId = ref.read(authControllerProvider).session?.userId;
    if (ownerId == null || currentUserId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave Workspace'),
          content: const Text('Are you sure you want to leave this workspace?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _isLeaving = true);
    try {
      await ref
          .read(workspaceServiceProvider)
          .removeMember(ownerId, currentUserId);
      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) {
        return;
      }
      const LoginRoute().go(context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to leave workspace right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }
}
