import 'dart:io';
import 'package:alpha2/screens/datastorage.dart';
import 'package:alpha2/screens/reviewpage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:animate_do/animate_do.dart';

class PANDetails extends StatefulWidget {
  final String userCode;
  const PANDetails({
    super.key,
    required this.userCode,
  });

  @override
  State<PANDetails> createState() => _PANDetailsState();
}

class _PANDetailsState extends State<PANDetails> {
  final TextEditingController _panNumberController = TextEditingController();
  final DataStorageService _dataStorage = DataStorageService();

  File? _selectedPANDocument;
  bool _isLoading = false;

  Map<String, String> _parsePANText(String fullText) {
    final result = <String, String>{};

    // Parse PAN number - Format: AAAAA0000A
    final panMatch = RegExp(r'[A-Z]{5}[0-9]{4}[A-Z]{1}').firstMatch(fullText);
    if (panMatch != null) {
      result['PAN Number'] = panMatch.group(0)!;
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
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop PAN Image',
              toolbarColor: Colors.orange[900],
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false, // Allow free-form cropping
            ),
            IOSUiSettings(
              title: 'Crop PAN Image',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _selectedPANDocument = File(croppedFile.path);
            _isLoading = true;
          });
          await _extractPANDetails(_selectedPANDocument!);
        }
      }
    } catch (e) {
      print('Error capturing or cropping image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing or cropping image: $e')),
      );
    }
  }

  Future<void> _extractPANDetails(File file) async {
    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFile(file);
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final parsedData = _parsePANText(recognizedText.text);
      setState(() {
        _panNumberController.text = parsedData['PAN Number'] ?? '';
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

  void _submit() {
    if (_selectedPANDocument == null || _panNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload PAN document and fill details'),
        ),
      );
      return;
    }

    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$')
        .hasMatch(_panNumberController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid PAN number'),
        ),
      );
      return;
    }

    try {
      _dataStorage.savePANDetails(
        documentImage: _selectedPANDocument,
        panNumber: _panNumberController.text,
      );

      // Changed navigation to go to Review page instead of popping
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewPage(
              userCode:
                  widget.userCode), // Replace with your actual review page
        ),
      );
    } catch (e) {
      print('Error saving data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }

  void _skipPAN() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewPage(
            userCode:
                widget.userCode), // Or BankDetails if skipping should go there
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text("PAN Card Details",
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
                    child: _selectedPANDocument == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  color: Colors.grey, size: 40),
                              SizedBox(height: 8),
                              Text("Tap to capture PAN Card",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(_selectedPANDocument!,
                                fit: BoxFit.cover),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 70),
              FadeInUp(
                duration: const Duration(milliseconds: 1600),
                child: _buildTextField(_panNumberController, "PAN Number"),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: MaterialButton(
                  onPressed: _skipPAN,
                  height: 50,
                  color: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: const Text(
                    'Skip PAN',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: MaterialButton(
                  onPressed: _submit,
                  height: 50,
                  color: Colors.orange[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
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
    _panNumberController.dispose();
    super.dispose();
  }
}
