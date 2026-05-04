import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Post {
  String? id;
  String? image;
  String? description;
  String? category;
  Timestamp? createdAt;
  Timestamp? updateAt;
  String? latitude;
  String? longtitude;
  String? userId;
  String? fullname;

  Post({
    this.id,
    this.image,
    this.description,
    this.category,
    this.createdAt,
    this.updateAt,
    this.latitude,
    this.longtitude,
    this.userId,
    this.fullname,
  });

  factory Post.fromDocument(DocumentSnapshot doc){
    Map<String, dynamic> data = doc.data() as Map<String,dynamic>;
    return Post(
      id: doc.id,
      image: data['image'],
      description: data['description'],
      category: data['category'],
      createdAt: data['createdAt'],
      updateAt: data['updateAt'],
      latitude: data['latitude'],
      longtitude: data['longtitude'],
      userId: data['userId'],
      fullname: data['fullname'],
    );
  }
  Map<String,dynamic>toDocument(){
    return{
      'description': description,
      'image': image,
      'category': category,
      'createdAt': createdAt,
      'updateAt': updateAt,
      'latitude': latitude,
      'longtitude': longtitude,
      'userId': userId,
      'fullname': fullname,
    };
  }
}