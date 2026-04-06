import 'package:flutter/material.dart';

class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: const Text('Load more'));
  }
}
