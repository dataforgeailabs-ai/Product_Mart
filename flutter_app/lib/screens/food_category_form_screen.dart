import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_category.dart';
import '../services/food_service.dart';

class FoodCategoryFormScreen extends StatefulWidget {
  final int? categoryId;

  const FoodCategoryFormScreen({super.key, this.categoryId});

  @override
  State<FoodCategoryFormScreen> createState() =>
      _FoodCategoryFormScreenState();
}

class _FoodCategoryFormScreenState extends State<FoodCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FoodService();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _description = TextEditingController();
  List<FoodCategory> _categories = [];
  FoodCategory? _category;
  int? _parentCategory;
  File? _image;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingImage = false;
  String? _error;

  bool get _isEditing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await _service.getManagedFoodCategories();
      final category = _isEditing
          ? await _service.getFoodCategory(widget.categoryId!)
          : null;
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _category = category;
        if (category != null) {
          _name.text = category.name;
          _description.text = category.description;
          _parentCategory = category.parentCategory;
        }
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

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked != null && mounted) setState(() => _image = File(picked.path));
    } catch (error) {
      if (mounted) _showMessage('Unable to select image: $error', error: true);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'display_order': _category?.displayOrder ?? 0,
    };
    final selectedParent = _categories.where(
      (item) => item.id == _parentCategory,
    );
    final existingParentIsInactive = _isEditing &&
        _parentCategory == _category?.parentCategory &&
        selectedParent.isNotEmpty &&
        !selectedParent.first.isActive;
    if (!existingParentIsInactive) {
      fields['parent_category'] = _parentCategory;
    }
    try {
      if (_isEditing) {
        await _service.updateFoodCategory(
          id: widget.categoryId!,
          fields: fields,
          image: _image,
        );
      } else {
        await _service.createFoodCategory(fields: fields, image: _image);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage('Unable to save category: $error', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  String? _validateName(String? value) => value == null || value.trim().isEmpty
      ? 'Category name is required.'
      : null;

  Widget _buildImage() {
    final url = _category?.image;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Container(
            width: 180,
            height: 150,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _image != null
                ? Image.file(_image!, fit: BoxFit.cover)
                : url != null && url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                        ),
                      )
                    : const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isSaving || _isPickingImage ? null : _pickImage,
            icon: _isPickingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined),
            label: Text(
              url != null && url.isNotEmpty || _image != null
                  ? 'Change Image'
                  : 'Select Image',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Food Category' : 'Add Food Category'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadForm,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildImage(),
                        TextFormField(
                          controller: _name,
                          validator: _validateName,
                          decoration: const InputDecoration(
                            labelText: 'Category Name *',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _description,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int?>(
                          initialValue: _parentCategory,
                          decoration: const InputDecoration(
                            labelText: 'Parent Category (optional)',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('No parent category'),
                            ),
                            ..._categories
                                .where((item) => item.id != _category?.id)
                                .map(
                                  (item) => DropdownMenuItem<int?>(
                                    value: item.id,
                                    child: Text(item.name),
                                  ),
                                ),
                          ],
                          onChanged: (value) =>
                              setState(() => _parentCategory = value),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isSaving
                                  ? 'Saving...'
                                  : _isEditing
                                      ? 'Update Category'
                                      : 'Save Category',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      );
}
