import 'package:cepu_app/firebase_options.dart';
import 'package:cepu_app/screens/home_screen.dart';
import 'package:cepu_app/screens/sign_in_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StreamBuilder(stream: FirebaseAuth.instance.authStateChanges(), 
      builder: (context, snapshot) {
        if(snapshot.hasData){
          return HomeScreen();
        } else {
          return SignInScreen();
        }
      }),
      );
  }
}