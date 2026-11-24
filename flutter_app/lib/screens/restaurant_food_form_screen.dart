import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_category.dart';
import '../models/food_item.dart';
import '../services/food_service.dart';
import '../services/hotel_service.dart';

class RestaurantFoodFormScreen extends StatefulWidget {
  final int? foodItemId;
  final bool adminMode;

  const RestaurantFoodFormScreen({
    super.key,
    this.foodItemId,
    this.adminMode = false,
  });

  @override
  State<RestaurantFoodFormScreen> createState() =>
      _RestaurantFoodFormScreenState();
}

class _RestaurantFoodFormScreenState extends State<RestaurantFoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FoodService();
  final _hotelService = HotelService();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _preparationTime = TextEditingController(text: '15');
  final _servingSize = TextEditingController();
  final _ingredients = TextEditingController();
  final _allergens = TextEditingController();

  List<FoodCategory> _categories = [];
  List<Map<String, dynamic>> _hotels = [];
  FoodItem? _item;
  int? _category;
  int? _hotelId;
  String _foodType = 'VEG';
  String _spiceLevel = '';
  bool _isAvailable = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingImage = false;
  File? _image;
  String? _error;

  bool get _isEditing => widget.foodItemId != null;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _preparationTime.dispose();
    _servingSize.dispose();
    _ingredients.dispose();
    _allergens.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = widget.adminMode
          ? await _service.getManagedFoodCategories()
          : await _service.getFoodCategories();
      final item = _isEditing
          ? await _service.getFoodItem(widget.foodItemId!)
          : null;
      final hotels = widget.adminMode ? await _hotelService.getHotels() : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _item = item;
        _hotels = hotels;
        if (item != null) {
          _name.text = item.name;
          _description.text = item.description;
          _price.text = item.price.toString();
          _preparationTime.text = item.preparationTime.toString();
          _servingSize.text = item.servingSize;
          _ingredients.text = item.ingredients;
          _allergens.text = item.allergens;
          _category = item.category;
          _hotelId = item.hotel;
          _foodType = item.foodType;
          _spiceLevel = item.spiceLevel;
          _isAvailable = item.isAvailable;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _positivePrice(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) {
      return 'Enter a price greater than zero.';
    }
    return null;
  }

  String? _validPreparation(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) {
      return 'Enter a valid preparation time in minutes.';
    }
    return null;
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
    } catch (e) {
      if (mounted) _showMessage('Unable to select image: $e', error: true);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_category == null) {
      _formKey.currentState!.validate();
      return;
    }
    setState(() => _isSaving = true);
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': double.parse(_price.text.trim()).toStringAsFixed(2),
      'food_type': _foodType,
      'preparation_time': int.parse(_preparationTime.text.trim()),
      'serving_size': _servingSize.text.trim(),
      'spice_level': _spiceLevel,
      'ingredients': _ingredients.text.trim(),
      'allergens': _allergens.text.trim(),
      'is_available': _isAvailable,
    };
    final selectedCategory = _categories.where((item) => item.id == _category);
    if (selectedCategory.isNotEmpty &&
        (selectedCategory.first.isActive || _category != _item?.category)) {
      fields['category'] = _category;
    }
    if (widget.adminMode && (!_isEditing || _hotelId != _item?.hotel)) {
      fields['hotel'] = _hotelId;
    }
    try {
      if (_isEditing) {
        await _service.updateFoodItem(
          id: widget.foodItemId!,
          fields: fields,
          image: _image,
        );
      } else {
        await _service.createFoodItem(fields: fields, image: _image);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to save food item: $e', error: true);
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

  Widget _textField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _imageSection() {
    final url = _item?.image;
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
                        : const Center(child: CircularProgressIndicator()),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Food' : 'Add Food')),
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
          : _categories.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No active food categories are available.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _imageSection(),
                  Text(
                    'Food Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _textField('Food Name *', _name, validator: _required),
                  if (widget.adminMode)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<int>(
                        initialValue: _hotelId,
                        decoration: const InputDecoration(
                          labelText: 'Restaurant *',
                        ),
                        items: _hotels
                            .where((hotel) =>
                                hotel['status'] == 'ACTIVE' ||
                                hotel['id'] == _hotelId)
                            .map(
                              (hotel) => DropdownMenuItem<int>(
                                value: (hotel['id'] as num).toInt(),
                                child: Text(hotel['name']?.toString() ?? 'Restaurant'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _hotelId = value),
                        validator: (value) => value == null
                            ? 'Please select a restaurant.'
                            : null,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<int>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                      ),
                      items: _categories
                          .where((category) =>
                              category.isActive || category.id == _item?.category)
                          .map(
                            (category) => DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _category = value),
                      validator: (value) {
                        if (value == null) return 'Please select a category.';
                        final selected = _categories
                            .where((category) => category.id == value);
                        if (selected.isNotEmpty &&
                            !selected.first.isActive &&
                            value != _item?.category) {
                          return 'Select an active food category.';
                        }
                        return null;
                      },
                    ),
                  ),
                  _textField('Description', _description, maxLines: 3),
                  _textField(
                    'Price *',
                    _price,
                    validator: _positivePrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _foodType,
                    decoration: const InputDecoration(labelText: 'Food Type'),
                    items: const [
                      DropdownMenuItem(value: 'VEG', child: Text('VEG')),
                      DropdownMenuItem(
                        value: 'NON_VEG',
                        child: Text('NON_VEG'),
                      ),
                      DropdownMenuItem(value: 'VEGAN', child: Text('VEGAN')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _foodType = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    'Preparation Time (minutes)',
                    _preparationTime,
                    validator: _validPreparation,
                    keyboardType: TextInputType.number,
                  ),
                  _textField('Serving Size', _servingSize),
                  DropdownButtonFormField<String>(
                    initialValue: _spiceLevel,
                    decoration: const InputDecoration(labelText: 'Spice Level'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Not specified')),
                      DropdownMenuItem(value: 'MILD', child: Text('MILD')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('MEDIUM')),
                      DropdownMenuItem(value: 'HOT', child: Text('HOT')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _spiceLevel = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  _textField('Ingredients', _ingredients, maxLines: 2),
                  _textField('Allergens', _allergens, maxLines: 2),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available for ordering'),
                    value: _isAvailable,
                    onChanged: (value) => setState(() => _isAvailable = value),
                  ),
                  const SizedBox(height: 20),
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
                            ? 'Update Food'
                            : 'Save Food',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
