class WorkspaceLimitException implements Exception {
  const WorkspaceLimitException([
    this.message = 'Workspace member limit reached',
  ]);

  final String message;

  @override
  String toString() => message;
}

class MemberNotFoundException implements Exception {
  const MemberNotFoundException([this.message = 'Member not found']);

  final String message;

  @override
  String toString() => message;
}
