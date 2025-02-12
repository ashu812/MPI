import 'dart:io';
import 'dart:math';

import 'package:alpha2/screens/adharback.dart';
import 'package:alpha2/screens/datastorage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:animate_do/animate_do.dart';

class AadhaarDetails extends StatefulWidget {
  final String userCode;
  const AadhaarDetails({
    super.key,
    required this.userCode,
  });

  @override
  State<AadhaarDetails> createState() => _AadhaarDetailsState();
}

class _AadhaarDetailsState extends State<AadhaarDetails> {
  final TextEditingController _aadhaarNumberController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final DataStorageService _dataStorage = DataStorageService();

  File? _selectedAadhaarDocument;
  bool _isLoading = false;

  Map<String, String> _parseAadhaarText(String fullText) {
    final result = <String, String>{};
    final lines = fullText.split('\n');

    final blacklist = [
      'government',
      'govern',
      'governm',
      'india',
      'issue',
      'download',
      'year of birth',
      'unique identification authority',
      'uidai',
      'vid'
    ];

    // Clean and process lines for name extraction
    final cleanedLines = lines
        .map((line) => line.trim())
        .where((line) =>
            !blacklist.any((term) => line.toLowerCase().contains(term)) &&
            !RegExp(r'\d').hasMatch(line))
        .toList();

    // Extract name
    if (cleanedLines.isNotEmpty) {
      final possibleName = cleanedLines.first;
      if (RegExp(r'^[a-zA-Z\s]+$').hasMatch(possibleName) &&
          !possibleName.toLowerCase().contains('male') &&
          !possibleName.toLowerCase().contains('female')) {
        result['Name'] = possibleName.capitalizeFirst();
      }
    }

    // More specific DOB extraction
    // Look for date patterns that come after "DOB:" or "Date of Birth:" or "Birth"
    final dobPattern = RegExp(
      r'(?:DOB|Date of Birth|Birth)\s*:?\s*(\d{2}/\d{2}/\d{4})',
      caseSensitive: false,
    );
    final dobMatch = dobPattern.firstMatch(fullText);
    if (dobMatch != null) {
      result['Date of Birth'] = dobMatch.group(1)!;
    } else {
      // Fallback: Look for dates that aren't preceded by "issued" or "printed"
      final dates = RegExp(r'\b\d{2}/\d{2}/\d{4}\b').allMatches(fullText);
      for (final date in dates) {
        // Get the text before this date (up to 20 characters)
        final startIndex = max(0, date.start - 20);
        final textBefore =
            fullText.substring(startIndex, date.start).toLowerCase();

        // If this date isn't preceded by issue/print related words, it's likely the DOB
        if (!textBefore.contains('issue') &&
            !textBefore.contains('print') &&
            !textBefore.contains('downloaded')) {
          result['Date of Birth'] = date.group(0)!;
          break;
        }
      }
    }

    // Extract gender
    final genderMatch =
        RegExp(r'\b(Male|Female)\b', caseSensitive: false).firstMatch(fullText);
    if (genderMatch != null) {
      result['Gender'] = genderMatch.group(0)!.capitalizeFirst();
    }

    // Extract Aadhaar number
    final aadhaarMatch =
        RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b').firstMatch(fullText);
    if (aadhaarMatch != null) {
      result['Aadhaar Number'] = aadhaarMatch.group(0)!.replaceAll(' ', '');
    }

    print("Parsed Data: $result");
    return result;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Aadhaar Front',
              toolbarColor: Colors.orange[900],
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false, // Allow free cropping
            ),
            IOSUiSettings(
              title: 'Crop Aadhaar Image',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _selectedAadhaarDocument = File(croppedFile.path);
          });

          // Ensure OCR is performed only on the cropped image
          await _extractAadhaarDetails(_selectedAadhaarDocument!);
        } else {
          // If cropping is skipped, don't use the original image
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cropping is required!')),
          );
        }
      }
    } catch (e) {
      print('Error capturing or cropping image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing or cropping image: $e')),
      );
    }
  }

  Future<void> _extractAadhaarDetails(File file) async {
    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFile(file);
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final parsedData = _parseAadhaarText(recognizedText.text);
      setState(() {
        _aadhaarNumberController.text = parsedData['Aadhaar Number'] ?? '';
        _nameController.text = parsedData['Name'] ?? '';
        _dobController.text = parsedData['Date of Birth'] ?? '';
        _genderController.text = parsedData['Gender'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      print("Error extracting text: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error extracting text: $e')),
      );
      setState(() => _isLoading = false);
    } finally {
      textRecognizer.close();
    }
  }

  void _saveAndNavigate() {
    if (_selectedAadhaarDocument == null ||
        _aadhaarNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload Aadhaar document and fill details'),
        ),
      );
      return;
    }

    try {
      // Validate Aadhaar number format
      if (!RegExp(r'^\d{12}$').hasMatch(_aadhaarNumberController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid 12-digit Aadhaar number'),
          ),
        );
        return;
      }

      // Save data to storage service
      _dataStorage.saveAadhaarFrontDetails(
        documentImage: _selectedAadhaarDocument,
        name: _nameController.text,
        dob: _dobController.text,
        gender: _genderController.text,
        aadhaarNumber: _aadhaarNumberController.text,
      );

      // Navigate to next page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AadhaarBackDetails(
            userCode: widget.userCode,
          ),
        ),
      );
    } catch (e) {
      print('Error saving data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text("Aadhaar Document Details",
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          spreadRadius: 5,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _selectedAadhaarDocument == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text("Tap to capture Aadhaar Document",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(_selectedAadhaarDocument!,
                                fit: BoxFit.cover),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 70),
              FadeInUp(
                duration: const Duration(milliseconds: 1600),
                child: _buildTextField(_nameController, "Enter Name"),
              ),
              const SizedBox(height: 30),
              FadeInUp(
                duration: const Duration(milliseconds: 1600),
                child: _buildTextField(_dobController, "Date of Birth"),
              ),
              const SizedBox(height: 30),
              FadeInUp(
                duration: const Duration(milliseconds: 1600),
                child: _buildTextField(_genderController, "Gender"),
              ),
              const SizedBox(height: 30),
              FadeInUp(
                duration: const Duration(milliseconds: 1600),
                child:
                    _buildTextField(_aadhaarNumberController, "Aadhaar Number"),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.shade100,
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            child: MaterialButton(
              onPressed: _saveAndNavigate,
              height: 50,
              minWidth: double.infinity,
              color: Colors.orange[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hintText) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade100,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: InputBorder.none,
            hintStyle: const TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _aadhaarNumberController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    super.dispose();
  }
}
