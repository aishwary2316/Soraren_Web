import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
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
  final ApiService _api = ApiService();
  XFile? _pickedFile;

  /// Handles image selection from Camera or Gallery
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 85);
    if (image != null) {
      if (!kIsWeb) {
        final isValid = await Validators.isValidImage(File(image.path));
        if (!isValid) {
          _showSnack('Security Error: Invalid file format', isError: true);
          return;
        }
      }
      setState(() => _pickedFile = image);
    }
  }

  /// Handles image selection from the File Picker (Browse)
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null) {
      if (kIsWeb) {
        // On Web, the path might be a blob URL
        setState(() => _pickedFile = XFile(result.files.single.path ?? ''));
      } else if (result.files.single.path != null) {
        final file = File(result.files.single.path!);
        if (await Validators.isValidImage(file)) {
          setState(() => _pickedFile = XFile(result.files.single.path!));
        } else {
          _showSnack('Security Error: Invalid file format', isError: true);
        }
      }
    }
  }

  /// Triggers the verification process defined in verification.dart
  void _identifySuspect() {
    if (_pickedFile == null) {
      _showSnack('Please select a suspect image to verify', isError: true);
      return;
    }

    // This call uses the helper function from verification.dart
    // to handle the loading dialog and API response before showing the dashboard.
    showVerificationDialog(
      context,
      api: _api,
      imagePath: _pickedFile!.path,
      location: 'Imphal-HQ', // Default location as per requirements
    );
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
      width: double.infinity,
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
            textAlign: TextAlign.center,
          ),
          Text("Official Database Access", style: TextStyle(color: Colors.grey)),
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
            child: kIsWeb
                ? Image.network(_pickedFile!.path, height: 250, width: 250, fit: BoxFit.cover)
                : Image.file(File(_pickedFile!.path), height: 250, width: 250, fit: BoxFit.cover),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _sourceButton(Icons.camera_alt, "Camera", () => _pickImage(ImageSource.camera)),
              const SizedBox(width: 8),
              _sourceButton(Icons.photo_library, "Gallery", () => _pickImage(ImageSource.gallery)),
              const SizedBox(width: 8),
              _sourceButton(Icons.folder_open, "Browse", _pickFile),
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
        onPressed: _identifySuspect,
        icon: const Icon(Icons.security),
        label: const Text("VERIFY IDENTITY", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _alertRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _alertRed : _policeBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}