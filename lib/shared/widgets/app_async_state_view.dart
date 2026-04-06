import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_empty_state.dart';
import 'app_failure_state.dart';

class AppAsyncStateView<T> extends StatelessWidget {
  const AppAsyncStateView({
    super.key,
    required this.state,
    required this.builder,
    this.isEmpty,
    this.emptyTitle = 'No data',
    this.emptyMessage = 'Nothing to show here yet.',
    this.emptyAction,
    this.onRetry,
  });

  final AsyncValue<T> state;
  final Widget Function(T data) builder;
  final bool Function(T data)? isEmpty;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? emptyAction;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (data) {
        final empty = isEmpty?.call(data) ?? false;
        if (empty) {
          return AppEmptyState(
            title: emptyTitle,
            message: emptyMessage,
            action: emptyAction,
          );
        }
        return builder(data);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          AppFailureState(message: error.toString(), onRetry: onRetry),
    );
  }
}
