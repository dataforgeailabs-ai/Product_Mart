import 'package:flutter/material.dart';

import '../services/hotel_service.dart';

class AdminHotelsScreen extends StatefulWidget {
  const AdminHotelsScreen({super.key});

  @override
  State<AdminHotelsScreen> createState() => _AdminHotelsScreenState();
}

class _AdminHotelsScreenState extends State<AdminHotelsScreen> {
  final HotelService _hotelService = HotelService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _hotels = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHotels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hotels = await _hotelService.getHotels();

      if (!mounted) return;

      setState(() {
        _hotels = hotels;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredHotels {
    final search = _searchController.text.trim().toLowerCase();

    return _hotels.where((hotel) {
      return search.isEmpty ||
          (hotel['name'] ?? '').toString().toLowerCase().contains(search) ||
          (hotel['email'] ?? '').toString().toLowerCase().contains(search) ||
          (hotel['city'] ?? '').toString().toLowerCase().contains(search);
    }).toList();
  }

  Color _statusColor(String status) {
    return status == 'ACTIVE' ? Colors.green : Colors.red;
  }

  Future<void> _updateStatus(
    Map<String, dynamic> hotel,
    String newStatus,
  ) async {
    final isBlocking = newStatus == 'BLOCKED';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isBlocking ? 'Block Hotel' : 'Reactivate Hotel'),
          content: Text(
            isBlocking
                ? 'Are you sure you want to block "${hotel['name']}"?'
                : 'Are you sure you want to reactivate "${hotel['name']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBlocking ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isBlocking ? 'Block' : 'Reactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await _hotelService.updateHotelStatus(
        hotelId: hotel['id'] as int,
        status: newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBlocking
                ? 'Hotel blocked successfully.'
                : 'Hotel reactivated successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _loadHotels();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update hotel status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showHotelDetails(Map<String, dynamic> hotel) {
    final status = hotel['status']?.toString() ?? 'UNKNOWN';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(hotel['name']?.toString() ?? 'Hotel Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Contact Person', hotel['contact_person']),
                _detailRow('Phone', hotel['phone']),
                _detailRow('Email', hotel['email']),
                _detailRow('Property Type', hotel['property_type']),
                _detailRow('Address', hotel['address']),
                _detailRow('City', hotel['city']),
                _detailRow('State', hotel['state']),
                _detailRow('PIN Code', hotel['pin_code']),
                _detailRow('GST Number', hotel['gst_number']),
                _detailRow('Status', status),
                _detailRow('Registered On', hotel['created_at']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    final text = value?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            text.isEmpty ? 'Not provided' : text,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelCard(Map<String, dynamic> hotel) {
    final status = hotel['status']?.toString() ?? 'UNKNOWN';
    final isActive = status == 'ACTIVE';
    final color = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.hotel_outlined,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotel['name']?.toString() ?? 'Unnamed Hotel',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hotel['city']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'details') {
                      _showHotelDetails(hotel);
                    } else if (value == 'toggle') {
                      _updateStatus(
                        hotel,
                        isActive ? 'BLOCKED' : 'ACTIVE',
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.block
                                : Icons.check_circle_outline,
                            color: isActive ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Block Hotel' : 'Reactivate'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hotel['contact_person']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.email_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hotel['email']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showHotelDetails(hotel),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadHotels,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final hotels = _filteredHotels;

    return RefreshIndicator(
      onRefresh: _loadHotels,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search hotel, email or city',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Registered Hotels',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${hotels.length} hotels',
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hotels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(
                    Icons.hotel_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text('No hotels found.'),
                ],
              ),
            )
          else
            ...hotels.map(_buildHotelCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadHotels,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}