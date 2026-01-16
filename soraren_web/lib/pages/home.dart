// lib/pages/home.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/validators.dart';
import 'verification.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  static const Color _policeBlue = Color(0xFF1E3A8A);
  static const Color _alertRed = Color(0xFFDC2626);

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _pickedFile;
  bool _isIdentifying = false;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (image != null) {
      // Security: Validate Magic Bytes
      if (!kIsWeb && !await Validators.isValidImage(File(image.path))) {
        _showSnack('Security Error: Invalid file format', isError: true);
        return;
      }
      setState(() => _pickedFile = image);
    }
  }

  Future<void> _identifySuspect() async {
    if (_pickedFile == null) {
      _showSnack('Please upload a suspect image', isError: true);
      return;
    }

    setState(() => _isIdentifying = true);
    try {
      // await verifyDriverAndShowDialog(
      //   context,
      //   driverImageFile: File(_pickedFile!.path),
      //   location: 'Manipur-HQ',
      //   tollgate: 'Main-Secure',
      // );
    } catch (e) {
      _showSnack('Identification failed: $e', isError: true);
    } finally {
      setState(() => _isIdentifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 30),
          _buildUploadCard(),
          const SizedBox(height: 30),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _policeBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _policeBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: const [
          Icon(Icons.person_search, size: 50, color: _policeBlue),
          SizedBox(height: 10),
          Text(
            "Suspect Identification Portal",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _policeBlue),
          ),
          Text("Official Manipur Police Database Access", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        children: [
          _pickedFile == null
              ? Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.grey.shade300)
              : ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(File(_pickedFile!.path), height: 180, width: 180, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _sourceButton(Icons.camera_alt, "Camera", () => _pickImage(ImageSource.camera)),
              const SizedBox(width: 15),
              _sourceButton(Icons.photo_library, "Gallery", () => _pickImage(ImageSource.gallery)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: _isIdentifying ? null : _identifySuspect,
        icon: _isIdentifying ? const SizedBox.shrink() : const Icon(Icons.security),
        label: Text(_isIdentifying ? "PROCESSING..." : "IDENTIFY SUSPECT"),
        style: ElevatedButton.styleFrom(
          backgroundColor: _alertRed, // Red Action Button
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _sourceButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _policeBlue,
        side: const BorderSide(color: _policeBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? _alertRed : _policeBlue),
    );
  }
}