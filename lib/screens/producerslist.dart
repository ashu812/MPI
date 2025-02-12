import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MilkProducersListScreen extends StatefulWidget {
  const MilkProducersListScreen({super.key});

  @override
  State<MilkProducersListScreen> createState() =>
      _MilkProducersListScreenState();
}

class _MilkProducersListScreenState extends State<MilkProducersListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Producers List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _selectedFilter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'approved', child: Text('Approved')),
              const PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by VLC Name or Code...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .orderBy('name', descending: !_sortAscending)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final matchesSearch = data['vlcName']
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      data['vlcCode']
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());

                  final matchesFilter = _selectedFilter == 'all' ||
                      data['status'].toString().toLowerCase() ==
                          _selectedFilter;

                  return matchesSearch && matchesFilter;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No matching records found'));
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final data =
                          filteredDocs[index].data() as Map<String, dynamic>;
                      return _ProducerListItem(
                        producerName: data['name'] ?? 'N/A',
                        gender: data['gender'] ?? 'N/A',
                        vlcName: data['vlc_name'] ?? 'N/A',
                        vlcCode: data['vlc_code'] ?? 'N/A',
                        fathersname: data['fatherName'] ?? 'N/A',
                        mobilenumber: data['mobilenumber'] ?? 'N/A',
                        dob: data['dateOfBirth'] ?? 'N/A',
                        aadharno: data['aadharNumber'] ?? 'N/A',
                        bankname: data['bankName'] ?? 'N/A',
                        ifsc: data['ifscCode'] ?? 'N/A',
                        pannumber: data['panNumber'] ?? 'N/A',
                        address: data['address'] ?? 'N/A',
                        accountNo: data['accountNumber'] ?? 'N/A',
                        submissionDate: data['kycSubmissionDate']?.toDate(),
                        status: data['status'] ?? 'pending',
                        onTap: () => _showDetailsDialog(context, data),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Producer Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailItem(title: 'Milk Producer Name', value: data['name']),
              _DetailItem(title: 'Gender', value: data['gender']),
              _DetailItem(title: 'VLC Name', value: data['vlc_name']),
              _DetailItem(title: 'VLC Code', value: data['vlc_code']),
              _DetailItem(title: "Father's Name", value: data['fatherName']),
              _DetailItem(
                title: 'Mobile No.',
                value: data['mobilenumber'],
              ),
              _DetailItem(
                title: 'DOB',
                value: data['dateOfBirth'],
              ),
              _DetailItem(title: 'Bank Name', value: data['bankName']),
              _DetailItem(
                title: 'Account No',
                value: data['accountNumber'],
              ),
              _DetailItem(title: 'IFSC', value: data['ifscCode']),
              _DetailItem(title: 'Bank Branch', value: data['branchName']),
              _DetailItem(
                title: 'PAN No.',
                value: data['panNumber'] ?? 'N/A',
              ),
              _DetailItem(
                title: 'Submission Date',
                value: DateFormat('dd MMM yyyy – HH:mm')
                    .format(data['kycSubmissionDate'].toDate()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ProducerListItem extends StatelessWidget {
  final String aadharno;
  final String vlcName;
  final String vlcCode;
  final String gender;
  final String producerName;
  final DateTime? submissionDate;
  final String status;
  final String bankname;
  final String ifsc;
  final String mobilenumber;

  final String accountNo;
  final String pannumber;
  final String fathersname;
  final String dob;
  final String address;
  final VoidCallback onTap;

  const _ProducerListItem({
    required this.address,
    required this.dob,
    required this.fathersname,
    required this.pannumber,
    required this.mobilenumber,
    required this.gender,
    required this.ifsc,
    required this.bankname,
    required this.accountNo,
    required this.aadharno,
    required this.vlcName,
    required this.vlcCode,
    required this.producerName,
    this.submissionDate,
    required this.status,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 60,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producerName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$vlcName ($vlcCode)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (submissionDate != null)
                    Text(
                      DateFormat('dd MMM yyyy – HH:mm').format(submissionDate!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String title;
  final String value;

  const _DetailItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
