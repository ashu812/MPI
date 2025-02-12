import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class KycData {
  String? code;
  String? vlcName;
  String? vlcCode;
  String? mobileNumber;
  String? profilePhotoUrl;
  File? profilePhoto;

  // Existing KYC Fields
  File? aadhaarFrontImage;
  File? aadhaarBackImage;
  File? bankDocument;
  File? panCardImage; // Added PAN card image
  String? name;
  String? dateOfBirth;
  String? gender;
  String? aadhaarNumber;
  String? panNumber; // Added PAN number
  String? fatherName;
  String? address;
  String? bankName;
  String? ifscCode;
  String? accountNumber;
  String? branchName;

  Map<String, dynamic> toJson() {
    return {
      // Basic Details
      'code': code,
      'vlc_name': vlcName,
      'vlc_code': vlcCode,
      'profile_photo': profilePhotoUrl,
      'mobilenumber': mobileNumber,

      // KYC Details
      'name': name,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'aadhaarNumber': aadhaarNumber,
      'panNumber': panNumber, // Added PAN number to JSON
      'fatherName': fatherName,
      'address': address,
      'bankName': bankName,
      'ifscCode': ifscCode,
      'accountNumber': accountNumber,
      'branchName': branchName,
    };
  }
}

class DataStorageService {
  static final DataStorageService _instance = DataStorageService._internal();
  factory DataStorageService() => _instance;
  DataStorageService._internal();

  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 15, // 75% compression (100% - 75%)
    );

    return compressedFile != null ? File(compressedFile.path) : file;
    ; // fallback to original if compression fails
  }

  final KycData _kycData = KycData();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  // Clear all stored data
  Future<void> clearKycData() async {
    await storage.deleteAll();
  }

  // Save Basic Details
  void saveBasicDetails({
    required String mobileNumber,
    required File? profilePhoto,
    required String code,
    required String vlcName,
    required String vlcCode,
  }) {
    _kycData.profilePhoto = profilePhoto;
    _kycData.mobileNumber = mobileNumber;
    _kycData.code = code;
    _kycData.vlcName = vlcName;
    _kycData.vlcCode = vlcCode;
  }

  // Get Basic Details
  Map<String, String?> getBasicDetails() {
    return {
      'mobileNumber': _kycData.mobileNumber,
      'code': _kycData.code,
      'vlc_name': _kycData.vlcName,
      'vlc_code': _kycData.vlcCode,
      'profile_photo': _kycData.profilePhotoUrl,
    };
  }

  // New method for saving PAN details
  void savePANDetails({
    required File? documentImage,
    required String panNumber,
  }) {
    _kycData.panCardImage = documentImage;
    _kycData.panNumber = panNumber;
  }

  void saveAadhaarFrontDetails({
    required File? documentImage,
    required String name,
    required String dob,
    required String gender,
    required String aadhaarNumber,
  }) {
    _kycData.aadhaarFrontImage = documentImage;
    _kycData.name = name;
    _kycData.dateOfBirth = dob;
    _kycData.gender = gender;
    _kycData.aadhaarNumber = aadhaarNumber;
  }

  void saveAadhaarBackDetails({
    required File? documentImage,
    required String fatherName,
    required String address,
  }) {
    _kycData.aadhaarBackImage = documentImage;
    _kycData.fatherName = fatherName;
    _kycData.address = address;
  }

  void saveBankDetails({
    required File? documentImage,
    required String bankName,
    required String ifscCode,
    required String accountNumber,
    required String branchName,
  }) {
    _kycData.bankDocument = documentImage;
    _kycData.bankName = bankName;
    _kycData.ifscCode = ifscCode;
    _kycData.accountNumber = accountNumber;
    _kycData.branchName = branchName;
  }

  KycData getKycData() => _kycData;

  Future<void> uploadAllData(String userCode) async {
    try {
      String? profilePhotoUrl;
      if (_kycData.profilePhoto != null) {
        final compressedProfile = await _compressImage(_kycData.profilePhoto!);
        final profileRef = FirebaseStorage.instance
            .ref('profile_photos/${userCode}_profile.jpg');
        await profileRef.putFile(compressedProfile);
        profilePhotoUrl = await profileRef.getDownloadURL();
      }
      // Compress and upload Aadhaar front image
      final compressedFront = await _compressImage(_kycData.aadhaarFrontImage!);
      final frontImageRef = FirebaseStorage.instance
          .ref('aadhaar_docs/${userCode}_aadhaar_front.jpg');
      await frontImageRef.putFile(compressedFront);
      final frontImageUrl = await frontImageRef.getDownloadURL();

      // Compress and upload Aadhaar back image
      final compressedBack = await _compressImage(_kycData.aadhaarBackImage!);
      final backImageRef = FirebaseStorage.instance
          .ref('aadhaar_docs/${userCode}_aadhaar_back.jpg');
      await backImageRef.putFile(compressedBack);
      final backImageUrl = await backImageRef.getDownloadURL();

      // Compress and upload bank document
      final compressedBank = await _compressImage(_kycData.bankDocument!);
      final bankDocRef =
          FirebaseStorage.instance.ref('bank_docs/${userCode}_bank_doc.jpg');
      await bankDocRef.putFile(compressedBank);
      final bankDocUrl = await bankDocRef.getDownloadURL();

      // Compress and upload PAN card image if available
      String? panCardUrl;
      if (_kycData.panCardImage != null) {
        final compressedPan = await _compressImage(_kycData.panCardImage!);
        final panCardRef =
            FirebaseStorage.instance.ref('pan_docs/${userCode}_pan_card.jpg');
        await panCardRef.putFile(compressedPan);
        panCardUrl = await panCardRef.getDownloadURL();
      }

      // Get the document reference
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(userCode);

      // Prepare the data to update - now including VLC details
      final data = {
        'profile_photo': profilePhotoUrl,
        // Basic Details
        'vlc_name': _kycData.vlcName,
        'vlc_code': _kycData.vlcCode,
        'mobilenumber': _kycData.mobileNumber,

        // Existing KYC Details
        'aadhaarNumber': _kycData.aadhaarNumber,
        'panNumber': _kycData.panNumber,
        'name': _kycData.name,
        'dateOfBirth': _kycData.dateOfBirth,
        'gender': _kycData.gender,
        'fatherName': _kycData.fatherName,
        'address': _kycData.address,
        'bankName': _kycData.bankName,
        'ifscCode': _kycData.ifscCode,
        'accountNumber': _kycData.accountNumber,
        'branchName': _kycData.branchName,
        'aadhaarFrontImage': frontImageUrl,
        'aadhaarBackImage': backImageUrl,
        'bankDocImage': bankDocUrl,
        'panCardImage': panCardUrl,
        'kycStatus': 'completed',
        'kycSubmissionDate': FieldValue.serverTimestamp(),
      };

      // Update or create document
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await docRef.update(data);
      } else {
        await docRef.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('Error uploading data: $e');
    }
  }
}
