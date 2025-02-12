import 'dart:io';

import 'package:alpha2/screens/bankdocs.dart';
import 'package:alpha2/screens/datastorage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:animate_do/animate_do.dart';

class AadhaarBackDetails extends StatefulWidget {
  final String userCode;
  const AadhaarBackDetails({super.key, required this.userCode});

  @override
  State<AadhaarBackDetails> createState() => _AadhaarBackDetailsState();
}

class _AadhaarBackDetailsState extends State<AadhaarBackDetails> {
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final DataStorageService _dataStorage = DataStorageService();

  File? _selectedAadhaarBackDocument;
  bool _isLoading = false;

  Map<String, String> _parseAadhaarBackText(String fullText) {
    final result = <String, String>{};
    String processedText = fullText.toLowerCase();

    final stringBlacklist = [
      '1947',
      'help@uidai.gov.in',
      'www.uidai.gov.in',
      'print date',
    ];

    final patternBlacklist = [
      RegExp(r'\d{4}\s?\d{4}\s?\d{4}'),
      RegExp(r'\d{2}/\d{2}/\d{4}'),
    ];

    for (var item in stringBlacklist) {
      processedText = processedText.replaceAll(item.toLowerCase(), '');
    }

    for (var pattern in patternBlacklist) {
      processedText = processedText.replaceAll(pattern, '');
    }

    final relationshipPrefixes = [
      's/o',
      's.o',
      'S.O',
      'S/',
      's/',
      'd/',
      'D/',
      's/0',
      'd/o',
      'd/0',
      'c/o',
      'S/O',
      'S/0',
      'D/O',
      'D/0',
      'C/O'
    ];

    final startMarkers = [
      ...relationshipPrefixes.map((e) => '$e:'),
      'address:'
    ];
    int startIndex = -1;
    String startMarkerFound = '';

    for (var marker in startMarkers) {
      int index = processedText.indexOf(marker);
      if (index != -1) {
        if (startIndex == -1 || index < startIndex) {
          startIndex = index;
          startMarkerFound = marker;
        }
      }
    }

    if (startIndex != -1) {
      String relevantText =
          processedText.substring(startIndex + startMarkerFound.length).trim();

      // Remove relationship prefixes from father's name
      for (var prefix in relationshipPrefixes) {
        relevantText =
            relevantText.replaceAll('$prefix ', '').replaceAll('$prefix: ', '');
      }

      int commaIndex = relevantText.indexOf(',');
      if (commaIndex != -1) {
        String fatherName = relevantText.substring(0, commaIndex).trim();
        String remainingText = relevantText.substring(commaIndex + 1).trim();

        RegExp pincodeRegex = RegExp(r'\b\d{6}\b');
        Match? pincodeMatch = pincodeRegex.firstMatch(remainingText);

        String address = pincodeMatch != null
            ? remainingText.substring(0, pincodeMatch.end).trim()
            : remainingText.trim();

        result['Father Name'] = fatherName.capitalizeFirst();
        result['Address'] = address.capitalizeFirst();
      }
    }

    return result;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (pickedFile != null) {
        // Crop the image
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: ' Crop Adhar Address',
              toolbarColor: Colors.orange[900],
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false, // Allow free-form cropping
            ),
            IOSUiSettings(
              title: 'Crop Aadhaar Image',
              aspectRatioLockEnabled: true, // Lock aspect ratio
            ),
          ],
        );
        if (croppedFile != null) {
          setState(() {
            _selectedAadhaarBackDocument = File(croppedFile.path);
            _isLoading = true;
          });
          await _extractAadhaarBackDetails(_selectedAadhaarBackDocument!);
        }
      }
    } catch (e) {
      print('Error capturing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error capturing image. Please try again.')),
      );
    }
  }

  Future<void> _extractAadhaarBackDetails(File file) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(file);
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final parsedData = _parseAadhaarBackText(recognizedText.text);

      setState(() {
        _fatherNameController.text = parsedData['Father Name'] ?? '';
        _addressController.text = parsedData['Address'] ?? '';
        _isLoading = false;
      });

      // Show warning if fields are empty
      if (_fatherNameController.text.isEmpty ||
          _addressController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Some fields could not be extracted. Please check and fill manually if needed.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("Error extracting text: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Error extracting details. Please try again or enter manually.')),
      );
    } finally {
      textRecognizer.close();
    }
  }

  void _saveAndNavigate() {
    if (_selectedAadhaarBackDocument == null ||
        _fatherNameController.text.isEmpty ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all details')),
      );
      return;
    }

    try {
      // Validate and clean the data
      final fatherName = _fatherNameController.text.trim();
      final address = _addressController.text.trim();

      if (fatherName.isEmpty || address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields properly')),
        );
        return;
      }

      // Save data to storage service
      _dataStorage.saveAadhaarBackDetails(
        documentImage: _selectedAadhaarBackDocument,
        fatherName: fatherName,
        address: address,
      );

      // Navigate to bank documents page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BankDocs(userCode: widget.userCode),
        ),
      );
    } catch (e) {
      print('Error saving data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }

  Widget _buildTextField(TextEditingController controller, String hintText,
      {int maxLines = 1}) {
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
          maxLines: maxLines,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text("Aadhaar Back Details",
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
                    child: _selectedAadhaarBackDocument == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text("Tap to capture Aadhaar Back",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(_selectedAadhaarBackDocument!,
                                fit: BoxFit.cover),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 70),
              FadeInUp(
                duration: const Duration(milliseconds: 1600),
                child:
                    _buildTextField(_fatherNameController, "Guardian's Name"),
              ),
              const SizedBox(height: 30),
              FadeInUp(
                duration: const Duration(milliseconds: 1600),
                child:
                    _buildTextField(_addressController, "Address", maxLines: 3),
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

  @override
  void dispose() {
    _fatherNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}

extension StringCasing on String {
  String capitalizeFirst() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
}
