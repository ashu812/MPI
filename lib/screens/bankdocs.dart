import 'dart:io';
import 'package:alpha2/screens/datastorage.dart';
import 'package:alpha2/screens/pandetails.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:animate_do/animate_do.dart';

class BankDocs extends StatefulWidget {
  final String userCode;

  const BankDocs({super.key, required this.userCode});

  @override
  State<BankDocs> createState() => _BankDocsState();
}

class _BankDocsState extends State<BankDocs> {
  final DataStorageService _dataStorage = DataStorageService();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  File? _selectedBankDocument;
  bool _isLoading = false;
  String? selectedBank;
  bool isSearching = false;

  final List<String> banks = [
    'Allahabad Bank',
    'HDFC Bank',
    'Andhra Bank',
    'Axis Bank',
    'Bank of Bahrain and Kuwait',
    'Bank of Baroda',
    'Bank of India',
    'Bank of Maharashtra',
    'Canara Bank',
    'Central Bank of India',
    'City Union Bank',
    'Corporation Bank',
    'Deutsche Bank',
    'Development Credit Bank',
    'Dhanlaxmi Bank',
    'Federal Bank',
    'ICICI Bank',
    'IDBI Bank',
    'Indian Bank',
    'Indian Overseas Bank',
    'IndusInd Bank',
    'ING Vysya Bank',
    'Jammu and Kashmir Bank',
    'Karnataka Bank Ltd',
    'Karur Vysya Bank',
    'Kotak Bank',
    'Laxmi Vilas Bank',
    'Oriental Bank of Commerce',
    'Punjab National Bank',
    'Shamrao Vitthal Co-operative Bank',
    'South Indian Bank',
    'State Bank of Bikaner & Jaipur',
    'State Bank of Hyderabad State',
    'State Bank of India',
    'State Bank of Mysore',
    'State Bank of Patiala',
    'State Bank of Travancore',
    'Syndicate Bank',
    'Tamilnad Mercantile Bank Ltd.',
    'UCO Bank',
    'Union Bank of India',
    'United Bank of India',
    'Vijaya Bank',
    'Yes Bank',
  ];

  List<String> filteredBanks = [];

  @override
  void initState() {
    super.initState();
    filteredBanks = banks;
    _searchController.addListener(() {
      filterBanks();
    });
  }

  void filterBanks() {
    setState(() {
      if (_searchController.text.isEmpty) {
        filteredBanks = banks;
      } else {
        filteredBanks = banks
            .where((bank) => bank
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()))
            .toList();
      }
    });
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
              toolbarTitle: 'Crop Cheque Image',
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
      }
      if (pickedFile != null) {
        setState(() {
          _selectedBankDocument = File(pickedFile.path);
          _isLoading = true;
        });
        await _extractBankDetails(_selectedBankDocument!);
      }
    } catch (e) {
      print('Error capturing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error capturing image. Please try again.')),
      );
    }
  }

  Future<void> _extractBankDetails(File file) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(file);
    try {
      setState(() => _isLoading = true);

      final recognizedText = await textRecognizer.processImage(inputImage);
      final parsedData = _parseBankText(recognizedText.text);

      setState(() {
        if (parsedData['Account Number'] != null) {
          _accountNumberController.text = parsedData['Account Number']!;
        }
        _isLoading = false;
      });

      if (_accountNumberController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Account number could not be extracted. Please fill manually.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("Error extracting text: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Error extracting details. Please try again or enter manually.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      textRecognizer.close();
      setState(() => _isLoading = false);
    }
  }

  Map<String, String> _parseBankText(String fullText) {
    final result = <String, String>{};

    // Account number extraction
    final accountPatterns = RegExp(
        r'(?:A\/C No\.?|Account No\.?|AC No\.?|Account Number)\s*[:\-]?\s*(\d{9,18})');
    final match = accountPatterns.firstMatch(fullText);

    if (match != null) {
      result['Account Number'] = match.group(1)!;
    } else {
      final accNumMatches = RegExp(r'\b\d{9,18}\b').allMatches(fullText);
      if (accNumMatches.isNotEmpty) {
        final longestMatch = accNumMatches.reduce((curr, next) =>
            curr.group(0)!.length > next.group(0)!.length ? curr : next);
        result['Account Number'] = longestMatch.group(0)!;
      }
    }

    return result;
  }

  Map<String, String> _parseIFSCAndBranch(String fullText) {
    final result = <String, String>{};
    final lines = fullText.split('\n');

    // IFSC Code extraction patterns
    final ifscLabelPatterns = [
      RegExp(r'(?:IFSC|IFS)\s*(?:CODE)?\s*:?\s*([A-Z0-9]{11})',
          caseSensitive: false),
    ];

    int ifscLineIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].replaceAll(RegExp(r'\s+'), ' ');

      for (final pattern in ifscLabelPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null && match.group(1) != null) {
          String potentialIFSC = match.group(1)!;
          if (potentialIFSC.length == 11) {
            result['IFSC Code'] = potentialIFSC;
            ifscLineIndex = i;
            break;
          }
        }
      }
      if (ifscLineIndex != -1) break;
    }

    // Branch name extraction with improved patterns
    if (ifscLineIndex > 0) {
      for (int i = ifscLineIndex - 1; i >= 0; i--) {
        final line = lines[i].trim();
        // Check if line contains any form of branch indicator
        if (line.toUpperCase().contains('BR') ||
            line.toUpperCase().contains('BRANCH')) {
          // Don't remove 'Branch' or 'Br' from the name if it's part of the actual branch name
          String branchName = line;

          // Only remove standalone Branch/Br indicators
          branchName = branchName
              .replaceAll(
                  RegExp(r'^(?:BR|BRANCH)[,:\s]+', caseSensitive: false),
                  '') // Remove from start
              .replaceAll(
                  RegExp(r'[,:\s]+(?:BR|BRANCH)$', caseSensitive: false),
                  '') // Remove from end
              .trim();

          if (branchName.isNotEmpty) {
            result['Branch'] = branchName;
            break;
          }
        }
      }
    }

    // Fallback branch patterns
    if (result['Branch'] == null) {
      final branchPatterns = [
        RegExp(r'(?:Branch|Br)\s*:?\s*(.+?)(?=\n|$)', caseSensitive: false),
        RegExp(r'(?:Branch|Br)\s+Name\s*:?\s*(.+?)(?=\n|$)',
            caseSensitive: false),
      ];

      for (final pattern in branchPatterns) {
        final match = pattern.firstMatch(fullText);
        if (match != null && match.group(1) != null) {
          String branchName = match.group(1)!.trim();
          if (branchName.isNotEmpty) {
            result['Branch'] = branchName;
            break;
          }
        }
      }
    }

    return result;
  }

  Future<void> _pickIFSCImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          // Remove aspect ratio constraints
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop IFSC & Branch',
              toolbarColor: Colors.orange[900],
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false, // Allow free-form cropping
            ),
            IOSUiSettings(
              title: 'Crop IFSC & Branch',
              aspectRatioLockEnabled: false, // Disable aspect ratio lock
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() => _isLoading = true);
          final ifscImage = File(croppedFile.path);
          await _extractIFSCDetails(ifscImage);
          await ifscImage.delete();
        }
      }
    } catch (e) {
      print('Error capturing IFSC image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error capturing IFSC image')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractIFSCDetails(File file) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(file);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final parsedData = _parseIFSCAndBranch(recognizedText.text);

      setState(() {
        if (parsedData['IFSC Code'] != null) {
          _ifscController.text = parsedData['IFSC Code']!;
        }
        if (parsedData['Branch'] != null) {
          _branchController.text = parsedData['Branch']!;
        }
      });

      if (_ifscController.text.isEmpty || _branchController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract all details from IFSC image'),
          ),
        );
      }
    } catch (e) {
      print("Error extracting IFSC details: $e");
    } finally {
      textRecognizer.close();
    }
  }

  Future<void> _saveBankDetailsAndNavigate() async {
    if (_selectedBankDocument == null ||
        _ifscController.text.isEmpty ||
        _accountNumberController.text.isEmpty ||
        selectedBank == null ||
        _branchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all details and upload bank document')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save bank details using DataStorageService - FIXED LINE
      _dataStorage.saveBankDetails(
        documentImage: _selectedBankDocument,
        bankName: selectedBank!,
        ifscCode: _ifscController.text,
        accountNumber: _accountNumberController.text,
        branchName: _branchController.text, // Added branch name parameter
      );

      // Navigate to review page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PANDetails(userCode: widget.userCode),
        ),
      );
    } catch (e) {
      print('Error saving bank details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving bank details')),
      );
    }

    setState(() => _isLoading = false);
  }

  Widget _buildBankDropdown() {
    return FadeInUp(
      duration: const Duration(milliseconds: 1400),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search Bank",
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              filteredBanks = banks;
                            });
                          },
                        )
                      : null,
                ),
                onTap: () {
                  setState(() {
                    isSearching = true;
                  });
                },
              ),
            ),
            if (isSearching)
              Container(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredBanks.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(filteredBanks[index]),
                      onTap: () {
                        setState(() {
                          selectedBank = filteredBanks[index];
                          _searchController.text = filteredBanks[index];
                          isSearching = false;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
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

  // Add new controller

// Modify the IFSC field widget
  Widget _buildIFSCField() {
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
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ifscController,
                  decoration: const InputDecoration(
                    hintText: "IFSC Code",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.camera_alt, color: Colors.orange[900]),
                onPressed: _pickIFSCImage,
              ),
            ],
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
        title: const Text("Bank Document Details",
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
        child: GestureDetector(
          onTap: () {
            setState(() {
              isSearching = false;
            });
          },
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
                      child: _selectedBankDocument == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    color: Colors.grey, size: 40),
                                SizedBox(height: 8),
                                Text("Tap to capture Bank Document",
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(_selectedBankDocument!,
                                  fit: BoxFit.cover),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 70),
                _buildBankDropdown(),
                const SizedBox(height: 30),
                _buildTextField(
                    _accountNumberController, "Enter Account Number", true),
                const SizedBox(height: 30),
                _buildIFSCField(),
                const SizedBox(height: 30),
                _buildTextField(_branchController, "Branch Name", false),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildBottomButton() {
    return FadeInUp(
      duration: const Duration(milliseconds: 1800),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.shade100,
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.orange))
            : ElevatedButton(
                onPressed: _saveBankDetailsAndNavigate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[900],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _ifscController.dispose();
    _accountNumberController.dispose();
    _branchController.dispose(); // Added branch controller disposal
    _searchController.dispose();
    super.dispose();
  }
}
