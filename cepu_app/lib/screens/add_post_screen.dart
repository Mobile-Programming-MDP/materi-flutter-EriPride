import 'dart:convert';

import 'package:cepu_app/model/cepu.dart';
import 'package:cepu_app/services/cepu_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _image;
  Uint8List? _imageBytes;
  bool _isGenerating = false;
  List<String> categories = [
    "Jalan Rusak",
    "Lampu Jalan Mati",
    "Lawan Arah",
    "Merokok di Jalan",
    "Tidak Pakai Helm",
    "Lainnya"
  ];
  String? _category;
  String? _latitude;
  String? _longitude;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;


  Future<void> pickAndConvertThenCompressImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();

      var result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 80,
        minWidth: 1280,
        minHeight: 1280,
      );

      final encodedResult = base64Encode(result);

      setState(() {
        _image = encodedResult;
        _imageBytes = result;
      });
    }
  }

  Future<void> _generateDescriptionWithAI() async {
    if(_image == null){
      return;
    }

    setState(() {
      _isGenerating = true;
    });
    try{
      String apiKey = dotenv.env["API_KEY"] ?? '';
      String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$apiKey";
      final body = jsonEncode({
  "contents": [
    {
      "parts": [
        {
          "text": """
            Berdasarkan foto ini, identifikasi satu kategori utama kerusakan fasilitas umum dari daftar berikut:
            - Jalan Rusak
            - Lampu Jalan Mati
            - Lawan Arah
            - Merokok di Jalan
            - Tidak Pakai Helm
            - Lainnya

            Pilih kategori yang paling dominan atau paling mendesak untuk dilaporkan.

            Buat deskripsi singkat untuk laporan perbaikan dan tambahkan permohonan perbaikan.

            Fokus pada kerusakan yang terlihat dan hindari spekulasi.

            Format output:

            Kategori: [kategori]
            Deskripsi: [deskripsi]
            """
                    },
                    {
                      "inline_data": {
                        "mime_type": "image/jpeg",
                        "data": _image,
                      }
                    }
                  ]
                }
              ]
            });
      final headers = {'Content-Type' : 'application/json'};
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body:body
      );
      if(response.statusCode == 200){
        final jsonResponse = jsonDecode(response.body);
        final text = jsonResponse["candidates"][0]['content']['parts'][0]['text'];
        debugPrint(text);
        if(text!= null && text.isNotEmpty){
          final lines = text.trim().split('\n');
          String? aiCategory;
          String? aiDescription;
          for(var line in lines){
            final lower = line.toLowerCase();
            if(lower.startsWith('kategori:')){
              aiCategory = line.substring(9).trim();
            }else if (lower.startsWith('deskripsi:')){
              aiDescription = line.substring(11).trim();
            }
          }
          aiDescription ??= text.trim();
          setState(() {
            _category = aiCategory ?? "Lainnya";
            _descriptionController.text = aiDescription!;
          });

        }
      }
      else{
          debugPrint("Request Failed : ${response.body}");
        }
    } catch (e){
      debugPrint("Failed to generate AI description : $e");
    } finally{
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> sendNotificationToTopic(String body, String sendername) async {
    final url = Uri.parse("https://fasum-cloud-nkjt.vercel.app");
    final response = await http.post(
      url,
      headers: {
        "Content-Type" : "application/json"
      },
      body: jsonEncode({
        "topic" : "berita-fasum",
        "title" : "🔔Laporan Baru",
        "body" : body,
        "senderName" : sendername,
        "senderPhotoUrl" : "https://i.pinimg.com/originals/64/fd/9e/64fd9e71b07a0ea2f87ee45d2a65ceb2.jpg?nii=t"
      })
    );
    if(response.statusCode == 200 ){
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Notification Sent"))
        );
      }
    }else {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send notification"))
        );
      }
    }
  }

  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: categories.map((cat) {
            return ListTile(
              title: Text(cat),
              onTap: () {
                setState(() {
                  _category = cat;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Layanan Lokasi Tidak Aktif ")));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Akses Ditolak")));
          return;
        }
      }
      setState(() {
          _isGettingLocation = true;
      });
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _latitude = position.latitude.toString();
        _longitude = position.longitude.toString();
      });
      _isGettingLocation = false;

    } catch (e) {
      setState(() {
          _isGettingLocation = false;
        });
      debugPrint("Failed to retrieve location : $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengambil lokasi.")));
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    } 
  }

  Future<void> _submit() async {
    if (_image == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Isi gambar dan deskripsi"),
          backgroundColor: const Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final fullName = FirebaseAuth.instance.currentUser?.displayName ?? 'Pengguna';
    setState(() {
      _isSubmitting = true;
    });
    try {
      await _getLocation();
      await PostService.addPost(
        Post(
          category: _category ?? 'Lainnya',
          description: _descriptionController.text,
          fullname: fullName,
          userId: userId,
          image: _image,
          latitude: _latitude,
          longtitude: _longitude,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      sendNotificationToTopic(_descriptionController.text, fullName);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Data berhasil ditambahkan"),
          backgroundColor: const Color(0xFF1B5E20),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Terjadi Error : $e"),
            backgroundColor: const Color(0xFF1B5E20),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add new post")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _imageBytes == null
                ? Container(
                    height: 180,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: const Text('Belum ada gambar dipilih'),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _imageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : pickAndConvertThenCompressImage,
              child: const Text('Pick Image'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _showCategorySelector,
              child: const Text('Select Category'),
            ),
            const SizedBox(height: 8),
            Text(
              _category ?? 'Belum memilih kategori',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            OutlinedButton(
              onPressed: (_isGenerating || _isSubmitting)
                  ? null
                  : _generateDescriptionWithAI,
              child: Text(
                _isGenerating ? 'Membuat Deskripsi...' : 'Buat Deskripsi',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                hintText: 'Masukkan deskripsi laporan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: (_isSubmitting || _isGettingLocation)
                  ? null
                  : _getLocation,
              child: Text(
                _isGettingLocation ? 'Mengambil Lokasi...' : 'Get Location',
              ),
            ),
            const SizedBox(height: 8),
            _latitude == null || _longitude == null
                ? const Text('Lokasi belum diambil', textAlign: TextAlign.center,)
                : Text(
                    'Lat: $_latitude\nLng: $_longitude',
                    textAlign: TextAlign.center,
                  ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }
}