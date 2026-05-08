import 'dart:convert';
import 'dart:io';

import 'package:cepu_app/model/cepu.dart';
import 'package:cepu_app/services/cepu_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class addPostScreen extends StatefulWidget {
  const addPostScreen({super.key});

  @override
  State<addPostScreen> createState() => _addPostScreenState();
}

class _addPostScreenState extends State<addPostScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _base64Image;
  String? _latitude;
  String? _longitude;
  String? _category;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;

  List<String> get categories {
    return [
      'Jalan Rusak',
      'Lampu Jalan Mati',
      'Lawan Arah',
      'Merokok di Jalan',
      'Tidak Pakai Helm',
    ];
  }

  //1. Fungsi pick, and convert Image
  Future<void> pickImageAndConvert() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final compressedImage = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 50,
      );
      setState(() {
        _base64Image = base64Encode(compressedImage);
      });
    }
  }

  //2. Fungsi Get Geo Location
  Future<void> _getLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Layanan lokasi dinonaktifkan.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Izin lokasi ditolak.")));
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _latitude = position.latitude.toString();
        _longitude = position.longitude.toString();
      });
    } catch (e) {
      debugPrint('Failed to retrieve location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengambil lokasi.")));
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  //3. Fungsi tampil pilihan Kategori
  void _showCategorySelect() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
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

  Widget _buildImagePreview() {
    if (_base64Image == null) {
      return Container(
        height: 180,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: const Text('Belum ada gambar dipilih'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        base64Decode(_base64Image!),
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildLocationInfo() {
    if (_latitude == null || _longitude == null) {
      return const Text('Lokasi belum diambil');
    }

    return Text(
      'Lat: $_latitude\nLng: $_longitude',
      textAlign: TextAlign.center,
    );
  }

  //4. Fungsi submit post
  Future<void> _submitPost() async {
    if (_base64Image == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pilih gambar dan masukkan deskripsi")),
      );
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori terlebih dahulu.')),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan deskripsi terlebih dahulu.')),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });

    bool _isGenerating = false;

    Future<void> _generateDescriptionWithAI() async {
      if (_base64Image == null) return;
      setState(() => _isGenerating = true);
      try {
        const apiKey = 'AIzaSyDtX4uTw923UQaqMlJn-G2I_YMCSTIFrmI';
        const url =
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=$apiKey';
        final body = jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "inlineData": {
                    "mimeType": "image/jpeg",
                    "data": _base64Image,
                  },
                },
                {
                  "text":
                      "Berdasarkan foto ini, identifikasi satu kategori utama kerusakan fasilitas umum "
                      "dari daftar berikut: Jalan Rusak, Lampu Jalan Mati, Lawan Arah, Merokok di Jalan, Tidak Pakai Helm dan Lainnya. "
                      "Pilih kategori yang paling dominan atau paling mendesak untuk dilaporkan. "
                      "Buat deskripsi singkat untuk laporan perbaikan, dan tambahkan permohonan perbaikan. "
                      "Fokus pada kerusakan yang terlihat dan hindari spekulasi.\n\n"
                      "Format output yang diinginkan:\n"
                      "Kategori: [satu kategori yang dipilih]\n"
                      "Deskripsi: [deskripsi singkat]",
                },
              ],
            },
          ],
        });
        final headers = {'Content-Type': 'application/json'};
        final response = await http.post(
          Uri.parse(url),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          final text =
              jsonResponse['candidates'][0]['content']['parts'][0]['text'];
          print("AI TEXT: $text");
          if (text != null && text.isNotEmpty) {
            final lines = text.trim().split('\n');
            String? aicategory;
            String? aidescription;
            for (var line in lines) {
              final lower = line.toLowerCase();
              if (lower.startsWith('kategori:')) {
                aicategory = line.substring(9).trim();
              } else if (lower.startsWith('deskripsi:')) {
                aidescription = line.substring(11).trim();
              }
            }
            aidescription ??= text.trim();
            setState(() {
              _category = aicategory ?? 'Tidak diketahui';
              _descriptionController.text = aidescription!;
            });
          }
        } else {
          debugPrint('Request failed: ${response.body}');
        }
      } catch (e) {
        debugPrint('Failed to generate AI description: $e');
      } finally {
        if (mounted) setState(() => _isGenerating = false);
      }
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final fullName = FirebaseAuth.instance.currentUser?.displayName;
    try {
      if (_latitude == null || _longitude == null) {
        await _getLocation();
      }
      PostService.addPost(
        Post(
          image: _base64Image,
          description: _descriptionController.text,
          category: _category,
          latitude: _latitude,
          longtitude: _longitude,
          userId: userId,
          fullname: fullName,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Posting berhasil disimpan!")));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Posting gagal disimpan! : $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
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
            _buildImagePreview(),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : pickImageAndConvert,
              child: const Text('Pick Image'),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _showCategorySelect,
              child: const Text('Select Category'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                hintText: 'Masukkan deskripsi laporan',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: (_isSubmitting || _isGettingLocation)
                  ? null
                  : _getLocation,
              child: Text(
                _isGettingLocation ? 'Mengambil Lokasi...' : 'Get Location',
              ),
            ),
            const SizedBox(height: 8),
            _buildLocationInfo(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPost,
              child: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
