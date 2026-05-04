import 'dart:io';
import 'package:cepu_app/model/cepu.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class PostService {
  static final FirebaseFirestore _database = FirebaseFirestore.instance;
  static final CollectionReference _postCollection = _database.collection(
    'posts',
  );

  static Future<void> addPost(Post post) async {
    Map<String, dynamic> newNote = {
      "image": post.image,
      "description": post.description,
      "category": post.category,
      "createdAt": post.createdAt,
      "updateAt": post.updateAt,
      "latitude": post.latitude,
      "longtitude": post.longtitude,
      "userId": post.userId,
      "fullname": post.fullname,
    };
    await _postCollection.add(newNote);
  }

  static Stream<List<Post>> getPostList() {
    return _postCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Post(
          id: doc.id,
          image: data['image'],
          description: data['description'],
          category: data['category'],
          createdAt: data['createdAt'] != null
              ? data['createdAt'] as Timestamp
              : null,
          updateAt: data['updateAt'] != null
              ? data['updateAt'] as Timestamp
              : null,
          latitude: data['latitude'],
          longtitude: data['longtitude'],
          userId: data['userId'],
          fullname: data['fullname'],
        );
      }).toList();
    });
  }

  static Future<void> updatePost(Post post) async {
    Map<String, dynamic> updatePost = {
      "image": post.image,
      "description": post.description,
      "category": post.category,
      "createdAt": post.createdAt,
      'updateAt': FieldValue.serverTimestamp(),
      "latitude": post.latitude,
      "longtitude": post.longtitude,
      "userId": post.userId,
      "fullname": post.fullname,
    };
    await _postCollection.doc(post.id).update(updatePost);
  }

  static Future<void> deletePost(Post post) async {
    await _postCollection.doc(post.id).delete();
  }
}