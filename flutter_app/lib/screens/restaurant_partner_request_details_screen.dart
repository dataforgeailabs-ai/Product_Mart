import 'package:flutter/material.dart';

import '../models/restaurant_partner_request.dart';
import '../services/restaurant_partnership_service.dart';

class RestaurantPartnerRequestDetailsScreen extends StatefulWidget {
  final int requestId;

  const RestaurantPartnerRequestDetailsScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<RestaurantPartnerRequestDetailsScreen> createState() =>
      _RestaurantPartnerRequestDetailsScreenState();
}

class _RestaurantPartnerRequestDetailsScreenState
    extends State<RestaurantPartnerRequestDetailsScreen> {
  final RestaurantPartnershipService _service =
      RestaurantPartnershipService();
  RestaurantPartnerRequest? _request;
  bool _isLoading = true;
  bool _isReviewing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final request = await _service.getRequest(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = request;
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

  Future<bool> _confirmApproval() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Approve Partnership'),
          content: const Text(
            'Approve this restaurant partnership application?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      ) ??
      false;

  Future<String?> _askRejectionReason() async {
    final controller = TextEditingController();
    String? error;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reject Partnership'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Rejection reason *',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(() => error = 'Please provide a reason.');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _review({required bool approve}) async {
    final request = _request;
    if (request == null || request.status != 'PENDING' || _isReviewing) return;
    if (approve && !await _confirmApproval()) return;
    final reason = approve ? null : await _askRejectionReason();
    if (!approve && reason == null) return;

    setState(() => _isReviewing = true);
    try {
      final updated = approve
          ? await _service.approve(request.id)
          : await _service.reject(request.id, reason!);
      if (!mounted) return;
      setState(() {
        _request = updated;
        _isReviewing = false;
      });
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isReviewing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to review request: $error'),
          backgroundColor: Colors.red,
        ),
      );
      await _loadRequest();
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'Not available';
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(value.isEmpty ? 'Not provided' : value),
          ],
        ),
      );

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _request == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Request not found.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRequest,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final request = _request!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Status: ${request.status}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: request.status == 'APPROVED'
                        ? Colors.green.shade700
                        : request.status == 'REJECTED'
                            ? Colors.red.shade700
                            : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                _detail('Hotel Name', request.hotelName),
                _detail('Hotel Contact Person', request.hotelContactPerson),
                _detail('Hotel Phone', request.hotelPhone),
                _detail('Hotel Email', request.hotelEmail),
                _detail(
                  'Restaurant Name',
                  request.restaurantName.isEmpty
                      ? request.hotelName
                      : request.restaurantName,
                ),
                _detail('Restaurant Contact Number', request.restaurantPhone),
                _detail('FSSAI Licence Number', request.fssaiNumber),
                _detail('Restaurant Description', request.description),
                _detail('Application Date', _date(request.requestedAt)),
                if (request.reviewedAt != null)
                  _detail('Reviewed Date', _date(request.reviewedAt)),
                if (request.rejectionReason.isNotEmpty)
                  _detail('Rejection Reason', request.rejectionReason),
              ],
            ),
          ),
        ),
        if (request.status == 'PENDING') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isReviewing
                      ? null
                      : () => _review(approve: false),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isReviewing
                      ? null
                      : () => _review(approve: true),
                  child: _isReviewing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Partnership Request')),
        body: _buildContent(),
      );
}
