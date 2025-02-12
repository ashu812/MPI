import 'dart:io';
import 'package:alpha2/screens/adhardetaills.dart';
import 'package:alpha2/screens/datastorage.dart';
import 'package:alpha2/screens/producerslist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';

class BasicDetails extends StatefulWidget {
  const BasicDetails({super.key});

  @override
  State<BasicDetails> createState() => _BasicDetailsState();
}

class _BasicDetailsState extends State<BasicDetails> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _vlcNameController = TextEditingController();
  final TextEditingController _vlcCodeController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final DataStorageService _dataStorage = DataStorageService();
  XFile? _pickedImage;
  bool _isProcessing = false;
  String? selectedMccId;

  // MCC ID options
  final List<Map<String, String>> mccOptions = [
    {"id": "101", "name": "KHURJA"},
    {"id": "102", "name": "ANOOPSHAHR"},
    {"id": "103", "name": "KHAIR"},
    {"id": "104", "name": "ATROLI"},
    {"id": "118", "name": "SHAHABAD"},
    {"id": "114", "name": "DEVCHARA"},
    {"id": "113", "name": "FATEHABAD"},
    {"id": "105", "name": "BEHJOI"},
    {"id": "109", "name": "BILSI"},
    {"id": "107", "name": "SADABAD"},
    {"id": "120", "name": "BAH"},
    {"id": "121", "name": "ETAH"},
    {"id": "122", "name": "BAKEWAR"},
    {"id": "123", "name": "MAINPURI"},
    {"id": "124", "name": "KATRA"},
    {"id": "125", "name": "TIRWAGANJ"},
    {"id": "116", "name": "SHIKOHABAD"},
    {"id": "126", "name": "KUTHOND"},
    {"id": "128", "name": "TANDA"},
    {"id": "129", "name": "MOHDBD"},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() {
    final kycData = _dataStorage.getKycData();
    setState(() {
      _codeController.text = kycData.code ?? '';
      _vlcNameController.text = kycData.vlcName ?? '';
      _vlcCodeController.text = kycData.vlcCode ?? '';
      if (kycData.profilePhoto != null) {
        _pickedImage = XFile(kycData.profilePhoto!.path);
      }
    });
  }

  Future<void> _takePhoto() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressQuality: 80,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Colors.orange,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'Crop Image',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _pickedImage = XFile(croppedFile.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing photo: $e')),
      );
    }
  }

  Future<void> _saveAndNavigate() async {
    if (_pickedImage == null ||
        _codeController.text.isEmpty ||
        _vlcNameController.text.isEmpty ||
        _vlcCodeController.text.isEmpty ||
        selectedMccId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and take a photo.'),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      String code = _codeController.text.trim();

      // Concatenate MCC ID with VLC Code
      String completeVlcCode = selectedMccId! + _vlcCodeController.text.trim();

      // Compress the image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        _pickedImage!.path,
        '${_pickedImage!.path}_compressed.jpg',
        quality: 25,
      );

      if (compressedFile == null) {
        throw Exception('Image compression failed');
      }

      // Save to DataStorage
      _dataStorage.saveBasicDetails(
        profilePhoto: File(compressedFile.path),
        code: code,
        vlcName: _vlcNameController.text.trim(),
        mobileNumber: _numberController.text.trim(),
        vlcCode: completeVlcCode, // Save the concatenated VLC code
      );

      // Navigate to next page
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AadhaarDetails(userCode: code),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Widget _buildMccDropdown() {
    return FadeInUp(
      duration: const Duration(milliseconds: 1600),
      child: Container(
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
          child: DropdownButtonFormField<String>(
            value: selectedMccId,
            decoration: const InputDecoration(
              hintText: "Select MCC ID",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
            ),
            items: mccOptions.map((Map<String, String> option) {
              return DropdownMenuItem<String>(
                value: option["id"],
                child: Text("${option["id"]} - ${option["name"]}"),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                selectedMccId = newValue;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [
              Colors.orange.shade900,
              Colors.orange.shade800,
              Colors.orange.shade400
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInUp(
                    duration: const Duration(milliseconds: 1000),
                    child: const Text(
                      "Basic Profile",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Let's set up the Milk Producer's profile",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const MilkProducersListScreen()),
                            );
                          },
                          child: const Text(
                            "OR View All Milk Producers Registered",
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(60),
                    topRight: Radius.circular(60),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1400),
                          child: GestureDetector(
                            onTap: _takePhoto,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.shade200,
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.orange.shade100,
                                    blurRadius: 15,
                                    spreadRadius: -5,
                                    offset: const Offset(0, -5),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 70,
                                backgroundColor: Colors.white,
                                backgroundImage: _pickedImage != null
                                    ? FileImage(File(_pickedImage!.path))
                                    : null,
                                child: _pickedImage == null
                                    ? Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.orange.shade900,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildMccDropdown(), // Add MCC ID dropdown
                        const SizedBox(height: 10),
                        _buildTextField(
                            _codeController, "Milk Producer's Code", true),
                        const SizedBox(height: 10),
                        _buildTextField(_vlcNameController, "VLC Name", false),
                        const SizedBox(height: 10),
                        _buildTextField(_vlcCodeController, "VLC Code", true),
                        const SizedBox(height: 10),
                        _buildTextField(
                            _numberController, "Phone Number", true),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 80,
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
              onPressed: _isProcessing ? null : _saveAndNavigate,
              height: 50,
              minWidth: double.infinity,
              color: Colors.orange[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                _isProcessing ? 'Processing...' : 'Next',
                style: const TextStyle(
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

  Widget _buildTextField(
      TextEditingController controller, String hintText, bool isNumeric) {
    return FadeInUp(
      duration: const Duration(milliseconds: 1600),
      child: Container(
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
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            inputFormatters:
                isNumeric ? [FilteringTextInputFormatter.digitsOnly] : [],
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              hintStyle: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _vlcNameController.dispose();
    _vlcCodeController.dispose();
    _numberController.dispose();
    super.dispose();
  }
}
