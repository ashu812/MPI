import 'dart:io';
import 'package:alpha2/screens/datastorage.dart';
import 'package:alpha2/screens/basicdetails.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:alpha2/screens/tickanimation.dart';

class ReviewPage extends StatefulWidget {
  final String userCode;

  const ReviewPage({super.key, required this.userCode});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final DataStorageService _dataStorage = DataStorageService();
  bool _isLoading = false;

  Widget _buildSectionHeader(String title, IconData icon) {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange[800], size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.orange[900],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return FadeInUp(
      duration: const Duration(milliseconds: 1000),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.orange.shade50, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value.isNotEmpty ? value : 'Not Provided',
              style: TextStyle(
                fontSize: 16,
                color: value.isNotEmpty ? Colors.black87 : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentPreview(String title, File? image) {
    return FadeInUp(
      duration: const Duration(milliseconds: 1000),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                ),
                child: image != null
                    ? Stack(
                        children: [
                          Image.file(image, fit: BoxFit.cover),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'View',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                          size: 40,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitData() async {
    setState(() => _isLoading = true);
    try {
      await _dataStorage.uploadAllData(widget.userCode);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const TickAnimationsPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting data: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Map<String, String>> items,
  }) {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: Colors.orange[800], size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                    ),
                  ),
                ],
              ),
            ),

            // Section Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: items
                    .map((item) => _buildInfoItem(
                          label: item['label']!,
                          value: item['value']!,
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDataAndGoBack() async {
    await _dataStorage.clearKycData();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BasicDetails()),
      );
    }
  }

  Widget _buildInfoItem({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : 'Not Provided',
              style: TextStyle(
                fontSize: 15,
                color: value.isNotEmpty ? Colors.black87 : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kycData = _dataStorage.getKycData();

    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text("Review Application",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            )),
        backgroundColor: Colors.orange[900],
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Basic Information Card
              _buildSectionCard(
                title: "Basic Information",
                icon: Icons.person_outline,
                items: [
                  {'label': 'Milk Producer Code', 'value': kycData.code ?? ''},
                  {'label': 'VLC Code', 'value': kycData.vlcCode ?? ''},
                  {'label': 'VLC Name', 'value': kycData.vlcName ?? ''},
                  if (kycData.profilePhoto != null)
                    {'label': 'Profile Photo', 'value': 'Attached'},
                ],
              ),

              // Personal Details Card
              _buildSectionCard(
                title: "Personal Details",
                icon: Icons.fingerprint,
                items: [
                  {'label': 'Full Name', 'value': kycData.name ?? ''},
                  {
                    'label': 'Mobile Number',
                    'value': kycData.mobileNumber ?? ''
                  },
                  {
                    'label': 'Date of Birth',
                    'value': kycData.dateOfBirth ?? ''
                  },
                  {'label': 'Gender', 'value': kycData.gender ?? ''},
                  {'label': "Father's Name", 'value': kycData.fatherName ?? ''},
                ],
              ),

              // ID Documents Card
              _buildSectionCard(
                title: "Identity Documents",
                icon: Icons.assignment_outlined,
                items: [
                  {
                    'label': 'Aadhaar Number',
                    'value': kycData.aadhaarNumber ?? ''
                  },
                  if (kycData.panNumber != null &&
                      kycData.panNumber!.isNotEmpty)
                    {'label': 'PAN Number', 'value': kycData.panNumber ?? ''},
                  if (kycData.aadhaarFrontImage != null)
                    {'label': 'Aadhaar Front', 'value': 'Attached'},
                  if (kycData.aadhaarBackImage != null)
                    {'label': 'Aadhaar Back', 'value': 'Attached'},
                  if (kycData.panCardImage != null)
                    {'label': 'PAN Card', 'value': 'Attached'},
                ],
              ),

              // Bank Details Card
              _buildSectionCard(
                title: "Bank Details",
                icon: Icons.account_balance_outlined,
                items: [
                  {'label': 'Bank Name', 'value': kycData.bankName ?? ''},
                  {
                    'label': 'Account Number',
                    'value': kycData.accountNumber ?? ''
                  },
                  {'label': 'IFSC Code', 'value': kycData.ifscCode ?? ''},
                  {'label': 'Branch Name', 'value': kycData.branchName ?? ''},
                  if (kycData.bankDocument != null)
                    {'label': 'Bank Document', 'value': 'Attached'},
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[900],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm & Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _deleteDataAndGoBack,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Cancel Application',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
