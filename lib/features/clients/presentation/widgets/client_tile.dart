import 'package:flutter/material.dart';

import '../../domain/entities/client.dart';

class ClientTile extends StatelessWidget {
  const ClientTile({super.key, required this.client, required this.onTap});

  final Client client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: CircleAvatar(
        child: Text(
          client.name.isEmpty
              ? '?'
              : client.name.characters.first.toUpperCase(),
        ),
      ),
      title: Text(client.name),
      subtitle: Text(client.email),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
