import 'package:flutter/material.dart';

import '../models/food_category.dart';
import '../services/food_service.dart';
import 'food_category_form_screen.dart';

class FoodCategoryManagementScreen extends StatefulWidget {
  const FoodCategoryManagementScreen({super.key});

  @override
  State<FoodCategoryManagementScreen> createState() =>
      _FoodCategoryManagementScreenState();
}

class _FoodCategoryManagementScreenState
    extends State<FoodCategoryManagementScreen> {
  final FoodService _service = FoodService();
  List<FoodCategory> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await _service.getManagedFoodCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
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

  Future<void> _openForm({FoodCategory? category}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodCategoryFormScreen(categoryId: category?.id),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          category == null
              ? 'Food category added successfully.'
              : 'Food category updated successfully.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    await _loadCategories();
  }

  Future<void> _deactivate(FoodCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate Food Category'),
        content: Text('Deactivate "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deactivateFoodCategory(category.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food category deactivated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadCategories();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to deactivate category: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCategoryCard(FoodCategory category) {
    final parent = _categories.where((item) => item.id == category.parentCategory);
    final parentName = parent.isEmpty ? null : parent.first.name;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: category.image == null || category.image!.isEmpty
                  ? const Icon(Icons.category_outlined, size: 30)
                  : Image.network(
                      category.image!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                      errorBuilder: (context, error, stack) =>
                          const Icon(Icons.broken_image_outlined, size: 30),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (category.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(category.description),
                  ],
                  if (parentName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Parent: $parentName',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    category.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: category.isActive
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') _openForm(category: category);
                if (action == 'deactivate') _deactivate(category);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                if (category.isActive)
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Row(
                      children: [
                        Icon(Icons.block_outlined, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Deactivate'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                onPressed: _loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: _categories.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.category_outlined, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Center(child: Text('No food categories found.')),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) =>
                  _buildCategoryCard(_categories[index]),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Food Categories'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadCategories,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add Category'),
        ),
      );
}
