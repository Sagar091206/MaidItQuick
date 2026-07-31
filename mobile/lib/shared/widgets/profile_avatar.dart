import 'dart:convert';

import 'package:flutter/material.dart';

/// Circular avatar that renders a base64 data-URI photo when present and
/// falls back to the person's initials.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    this.photoDataUri,
    this.radius = 38,
  });

  final String initials;
  final String? photoDataUri;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = photoDataUri;
    if (photo != null && photo.isNotEmpty && photo.startsWith('data:')) {
      final comma = photo.indexOf(',');
      if (comma > 0) {
        try {
          final bytes = base64Decode(photo.substring(comma + 1));
          return CircleAvatar(
            radius: radius,
            backgroundColor: scheme.surfaceContainerHighest,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {
          // Fall through to the initials avatar.
        }
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.62,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
