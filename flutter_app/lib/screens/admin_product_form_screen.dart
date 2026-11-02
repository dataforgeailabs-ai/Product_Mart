import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../services/product_service.dart';

class AdminProductFormScreen extends StatefulWidget {
  final Product? product;

  const AdminProductFormScreen({
    super.key,
    this.product,
  });

  @override
  State<AdminProductFormScreen> createState() =>
      _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  final ImagePicker _imagePicker = ImagePicker();

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minimumOrderController = TextEditingController();
  final _minimumStockController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategory;
  String _selectedUnit = 'piece';

  File? _selectedImage;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingImage = false;
  String? _errorMessage;

  bool get _isEditing => widget.product != null;

  static const List<String> _units = [
    'piece',
    'kg',
    'gram',
    'litre',
    'ml',
    'packet',
    'box',
    'dozen',
    'bottle',
    'bag',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minimumOrderController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  Future<void> _initializeForm() async {
    final product = widget.product;

    if (product != null) {
      _nameController.text = product.name;
      _skuController.text = product.sku;
      _descriptionController.text = product.description;
      _priceController.text = product.price.toString();
      _stockController.text = product.stockQuantity.toString();
      _minimumOrderController.text =
          product.minimumOrderQuantity.toString();
      _minimumStockController.text =
          product.minimumStockLevel.toString();

      _selectedCategory = product.category;
      _selectedUnit = product.unit;
    }

    try {
      final categories = await _productService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;

        if (_selectedCategory == null && categories.isNotEmpty) {
          _selectedCategory = categories.first['id'] as int;
        }

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

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isPickingImage = true;
      });

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (!mounted) return;

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _validatePositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    final number = double.tryParse(value.trim());

    if (number == null || number <= 0) {
      return 'Enter a valid number greater than zero.';
    }

    return null;
  }

  String? _validateNonNegativeInteger(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    final number = int.tryParse(value.trim());

    if (number == null || number < 0) {
      return 'Enter a valid non-negative integer.';
    }

    return null;
  }

  String? _validateMinimumOrder(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    final number = int.tryParse(value.trim());

    if (number == null || number < 1) {
      return 'Minimum order quantity must be at least 1.';
    }

    return null;
  }

  Widget _buildImageSection() {
    final existingImage = widget.product?.image;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Image',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    )
                  : existingImage != null &&
                          existingImage.isNotEmpty
                      ? Image.network(
                          existingImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported_outlined,
                              size: 55,
                              color: Colors.grey,
                            );
                          },
                        )
                      : const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 55,
                          color: Colors.grey,
                        ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _isPickingImage || _isSaving
                    ? null
                    : _pickImage,
                icon: _isPickingImage
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: Text(
                  _selectedImage != null ||
                          (existingImage != null &&
                              existingImage.isNotEmpty)
                      ? 'Change Image'
                      : 'Select Image',
                ),
              ),
              if (_selectedImage != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove selected image',
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                  icon: const Icon(
                    Icons.close,
                    color: Colors.red,
                  ),
                ),
              ],
            ],
          ),
          const Center(
            child: Text(
              'Select a product image from your gallery.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        initialValue: _selectedCategory,
        decoration: InputDecoration(
          labelText: 'Category *',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        items: _categories.map((category) {
          return DropdownMenuItem<int>(
            value: category['id'] as int,
            child: Text(category['name'].toString()),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCategory = value;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a category.';
          }

          return null;
        },
      ),
    );
  }

  Widget _buildUnitDropdown() {
    final availableUnits = List<String>.from(_units);

    if (!availableUnits.contains(_selectedUnit)) {
      availableUnits.add(_selectedUnit);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedUnit,
        decoration: InputDecoration(
          labelText: 'Unit *',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        items: availableUnits.map((unit) {
          return DropdownMenuItem<String>(
            value: unit,
            child: Text(unit),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedUnit = value;
            });
          }
        },
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final category = _selectedCategory!;
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final sku = _skuController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final stock = int.parse(_stockController.text.trim());
      final minimumOrder =
          int.parse(_minimumOrderController.text.trim());
      final minimumStock =
          int.parse(_minimumStockController.text.trim());

      if (_isEditing) {
        await _productService.updateProduct(
          productId: widget.product!.id,
          category: category,
          name: name,
          description: description,
          sku: sku,
          price: price,
          stockQuantity: stock,
          minimumOrderQuantity: minimumOrder,
          minimumStockLevel: minimumStock,
          unit: _selectedUnit,
          image: _selectedImage,
        );
      } else {
        await _productService.createProduct(
          category: category,
          name: name,
          description: description,
          sku: sku,
          price: price,
          stockQuantity: stock,
          minimumOrderQuantity: minimumOrder,
          minimumStockLevel: minimumStock,
          unit: _selectedUnit,
          image: _selectedImage,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Product updated successfully.'
                : 'Product created successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildForm() {
    if (_categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No active categories found. Create a category before adding products.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildImageSection(),

          Text(
            'Basic Information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: 'Product Name *',
            controller: _nameController,
            validator: _validateRequired,
          ),

          _buildCategoryDropdown(),

          _buildTextField(
            label: 'SKU *',
            controller: _skuController,
            validator: _validateRequired,
          ),

          _buildTextField(
            label: 'Description',
            controller: _descriptionController,
            maxLines: 3,
          ),

          const SizedBox(height: 12),

          Text(
            'Pricing and Inventory',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            label: 'Price *',
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            validator: _validatePositiveNumber,
          ),

          _buildUnitDropdown(),

          _buildTextField(
            label: 'Stock Quantity *',
            controller: _stockController,
            keyboardType: TextInputType.number,
            validator: _validateNonNegativeInteger,
          ),

          _buildTextField(
            label: 'Minimum Order Quantity *',
            controller: _minimumOrderController,
            keyboardType: TextInputType.number,
            validator: _validateMinimumOrder,
          ),

          _buildTextField(
            label: 'Minimum Stock Level *',
            controller: _minimumStockController,
            keyboardType: TextInputType.number,
            validator: _validateNonNegativeInteger,
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProduct,
              icon: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
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
                        ? 'Update Product'
                        : 'Save Product',
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Product' : 'Add Product',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeForm,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildForm(),
    );
  }
}