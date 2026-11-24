import 'package:flutter/material.dart';

import '../models/restaurant_partner_request.dart';
import '../services/restaurant_partnership_service.dart';
import 'restaurant_partner_request_details_screen.dart';

class AdminRestaurantPartnerRequestsScreen extends StatefulWidget {
  const AdminRestaurantPartnerRequestsScreen({super.key});

  @override
  State<AdminRestaurantPartnerRequestsScreen> createState() =>
      _AdminRestaurantPartnerRequestsScreenState();
}

class _AdminRestaurantPartnerRequestsScreenState
    extends State<AdminRestaurantPartnerRequestsScreen> {
  final RestaurantPartnershipService _service =
      RestaurantPartnershipService();
  List<RestaurantPartnerRequest> _requests = [];
  bool _isLoading = true;
  bool _showAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final requests = await _service.getRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openDetails(RestaurantPartnerRequest request) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RestaurantPartnerRequestDetailsScreen(
          requestId: request.id,
        ),
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partnership request reviewed.'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadRequests();
    }
  }

  List<RestaurantPartnerRequest> get _visibleRequests => _showAll
      ? _requests
      : _requests.where((item) => item.status == 'PENDING').toList();

  Color _statusColor(String status) => switch (status) {
        'APPROVED' => Colors.green.shade700,
        'REJECTED' => Colors.red.shade700,
        _ => Colors.orange.shade800,
      };

  Widget _buildRequestCard(RestaurantPartnerRequest request) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
            child: Icon(
              Icons.restaurant_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            request.hotelName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.restaurantName.isEmpty
                      ? request.hotelName
                      : request.restaurantName,
                ),
                const SizedBox(height: 4),
                Text(request.restaurantPhone),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(request.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    request.status,
                    style: TextStyle(
                      color: _statusColor(request.status),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openDetails(request),
        ),
      );

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRequests,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final requests = _visibleRequests;
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Pending'),
                selected: !_showAll,
                onSelected: (_) => setState(() => _showAll = false),
              ),
              ChoiceChip(
                label: const Text('All Requests'),
                selected: _showAll,
                onSelected: (_) => setState(() => _showAll = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  const Icon(
                    Icons.hourglass_empty_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _showAll
                        ? 'No restaurant partnership requests found.'
                        : 'No pending restaurant partnership requests.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...requests.map(_buildRequestCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Restaurant Partnership Requests'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadRequests,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(),
      );
}
