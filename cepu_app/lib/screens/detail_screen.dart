import 'dart:convert';

import 'package:cepu_app/model/cepu.dart';
import 'package:cepu_app/screens/map_detail.screen.dart';
import 'package:cepu_app/services/cepu_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';


class DetailScreen extends StatelessWidget {
  final Post post;

  const DetailScreen({super.key, required this.post});

  Future<void> _deletePost(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PostService.deletePost(post);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _sharePost() {
    final text =
        '${post.category ?? ''}\n'
        '${post.description ?? ''}\n'
        'Posted by: ${post.fullname ?? ''}';

    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUserId != null && post.userId == currentUserId;

    final hasLocation = post.latitude != null && post.longtitude != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(post.category ?? 'Post Detail'),
        actions: [
          if (hasLocation)
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MapDetailScreen(post: post),
                  ),
                );
              },
              icon: const Icon(Icons.location_on),
              tooltip: 'View Location',
            ),
          IconButton(
            onPressed: _sharePost,
            icon: const Icon(Icons.share),
            tooltip: 'Share',
          ),
          if (isOwner)
            IconButton(
              onPressed: () => _deletePost(context),
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              color: Colors.red,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.image != null && post.image!.isNotEmpty)
              Image.memory(
                base64Decode(post.image!),
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 250,
                  child: Center(child: Icon(Icons.broken_image, size: 64)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.category != null) Chip(label: Text(post.category!)),
                  const SizedBox(height: 8),
                  Text(
                    post.description ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        post.fullname ?? 'Unknown',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.latitude}, ${post.longtitude}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
