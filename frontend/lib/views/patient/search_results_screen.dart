import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../components/doctor_card.dart';
import 'doctor_profile_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;
  final bool availableOnly;

  const SearchResultsScreen({
    super.key,
    required this.query,
    required this.availableOnly,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _results = [];
  Map<String, String?> _slots = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _apiService.searchDoctors(
        query: widget.query,
        availableOnly: widget.availableOnly,
      );

      // Collect all doctors across categories
      final allDoctors = <Map<String, dynamic>>[];
      for (final cat in results) {
        for (final doc in (cat['doctors'] as List)) {
          allDoctors.add(doc as Map<String, dynamic>);
        }
      }

      // Fetch earliest slots in parallel
      final slotResults = await Future.wait(
        allDoctors.map((doc) async {
          try {
            final slot = await _apiService.getEarliestSlot(doc['id'] as String);
            return MapEntry(doc['id'] as String, slot?['label'] as String?);
          } catch (_) {
            return MapEntry(doc['id'] as String, null);
          }
        }),
      );

      if (mounted) {
        setState(() {
          _results = results;
          _slots = Map.fromEntries(slotResults);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search failed. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search Results',
                style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.query, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _error != null
              ? _buildErrorView()
              : _results.isEmpty
                  ? _buildEmptyView()
                  : _buildResultsList(),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, style: GoogleFonts.inter()),
          TextButton(onPressed: _performSearch, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No doctors found matching your query.',
              style: GoogleFonts.inter(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    // Flatten into a single ordered list: header + cards per category
    final items = <_ListItem>[];
    int globalDoctorIndex = 0;

    for (final category in _results) {
      items.add(_ListItem.header(category['specialty'] as String, category['reason'] as String));
      for (final doc in (category['doctors'] as List)) {
        items.add(_ListItem.doctor(doc as Map<String, dynamic>, globalDoctorIndex));
        globalDoctorIndex++;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isHeader) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildCategoryHeader(item.specialty!, item.reason!),
          ).animate(delay: Duration(milliseconds: index * 50)).fadeIn(duration: 300.ms);
        }
        final doc = item.doc!;
        final docIndex = item.doctorIndex!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: DoctorCard(
            id: doc['id'] as String?,
            name: doc['full_name'] as String? ?? 'Doctor',
            specialty: doc['specialization'] as String? ?? '',
            experience: '${doc['experience_years']} yrs Exp',
            rating: (doc['rating'] as num?)?.toDouble() ?? 0.0,
            fee: 'PKR ${doc['consultation_fee']}',
            earliestSlot: _slots[doc['id']],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorProfileScreen(doctorId: doc['id'] as String),
              ),
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: 80 + docIndex * 100))
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.15, duration: 350.ms, curve: Curves.easeOut);
      },
    );
  }

  Widget _buildCategoryHeader(String specialty, String reason) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3C40).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B3C40).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(specialty,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1B3C40))),
          const SizedBox(height: 4),
          Text(reason, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700], height: 1.4)),
        ],
      ),
    );
  }
}

class _ListItem {
  final bool isHeader;
  final String? specialty;
  final String? reason;
  final Map<String, dynamic>? doc;
  final int? doctorIndex;

  const _ListItem._({required this.isHeader, this.specialty, this.reason, this.doc, this.doctorIndex});

  factory _ListItem.header(String specialty, String reason) =>
      _ListItem._(isHeader: true, specialty: specialty, reason: reason);

  factory _ListItem.doctor(Map<String, dynamic> doc, int index) =>
      _ListItem._(isHeader: false, doc: doc, doctorIndex: index);
}
