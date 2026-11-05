import 'package:flutter/material.dart';

/// "Qolani Moloi" -> "QM", "Qolani" -> "Q", "" -> "?".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// A person's round picture. Shows their profile photo when they have one,
/// and their initials only when they do not (or the picture can't load).
class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final Color color;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 20,
    this.color = const Color(0xFF667EEA),
  });

  Widget _initials() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initialsOf(name),
        style: TextStyle(color: Colors.white, fontSize: radius * 0.7, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url == null || url.isEmpty) return _initials();
    final size = radius * 2;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initials(),
        loadingBuilder: (context, child, progress) => progress == null ? child : _initials(),
      ),
    );
  }
}