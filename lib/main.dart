
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const StockInventoryApp());
}

// ============================================================
// APP CONFIGURATION
// ============================================================

const List<String> stockCategories = [
  'Electronics',
  'Stationery',
  'Hardware',
  'Grocery',
];

class StockInventoryApp extends StatelessWidget {
  const StockInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Inventory Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E40AF),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E5ED)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF2563EB),
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const InventoryHomePage(),
    );
  }
}

// ============================================================
// DASHBOARD AND INVENTORY
// ============================================================

class InventoryHomePage extends StatefulWidget {
  const InventoryHomePage({super.key});

  @override
  State<InventoryHomePage> createState() =>
      _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  final TextEditingController searchController =
  TextEditingController();
  final TextEditingController minQuantityController =
  TextEditingController();
  final TextEditingController maxQuantityController =
  TextEditingController();
  final TextEditingController minPriceController =
  TextEditingController();
  final TextEditingController maxPriceController =
  TextEditingController();

  String selectedCategory = 'All';
  String sortMode = 'quantityAsc';

  bool lowStockOnly = false;
  bool advancedSearchExpanded = false;

  late Stream<QuerySnapshot<Map<String, dynamic>>> inventoryStream;

  @override
  void initState() {
    super.initState();
    inventoryStream = db.collection('stockItems').snapshots();
  }

  @override
  void dispose() {
    searchController.dispose();
    minQuantityController.dispose();
    maxQuantityController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }

  void refreshInventory() {
    setState(() {
      inventoryStream = db.collection('stockItems').snapshots();
    });
  }

  Future<void> openAddStockPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddStockPage(),
      ),
    );

    if (result == true) {
      refreshInventory();
    }
  }

  void clearAllFilters() {
    setState(() {
      searchController.clear();
      minQuantityController.clear();
      maxQuantityController.clear();
      minPriceController.clear();
      maxPriceController.clear();

      selectedCategory = 'All';
      sortMode = 'quantityAsc';
      lowStockOnly = false;
    });
  }

  // ==========================================================
  // ADVANCED SEARCH FILTER LOGIC
  // All active filters must match (AND logic).
  // Keyword matches SKU OR item name.
  // ==========================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> filterItems(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
      ) {
    final keyword = searchController.text.trim().toLowerCase();

    final minQuantity =
    int.tryParse(minQuantityController.text.trim());
    final maxQuantity =
    int.tryParse(maxQuantityController.text.trim());

    final minPrice =
    double.tryParse(minPriceController.text.trim());
    final maxPrice =
    double.tryParse(maxPriceController.text.trim());

    final filtered = documents.where((document) {
      final data = document.data();

      final sku = (data['sku'] ?? '').toString().toLowerCase();
      final name =
      (data['itemName'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString();

      final quantity =
          (data['quantity'] as num?)?.toInt() ?? 0;
      final price =
          (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
      final reorderLevel =
          (data['reorderLevel'] as num?)?.toInt() ?? 0;

      // Quick search: partial SKU OR item name.
      final matchesKeyword = keyword.isEmpty ||
          sku.contains(keyword) ||
          name.contains(keyword);

      // Category filter.
      final matchesCategory = selectedCategory == 'All' ||
          category == selectedCategory;

      // Low stock filter.
      final matchesLowStock =
          !lowStockOnly || quantity <= reorderLevel;

      // Quantity range filters.
      final matchesMinQuantity =
          minQuantity == null || quantity >= minQuantity;

      final matchesMaxQuantity =
          maxQuantity == null || quantity <= maxQuantity;

      // Price range filters.
      final matchesMinPrice =
          minPrice == null || price >= minPrice;

      final matchesMaxPrice =
          maxPrice == null || price <= maxPrice;

      return matchesKeyword &&
          matchesCategory &&
          matchesLowStock &&
          matchesMinQuantity &&
          matchesMaxQuantity &&
          matchesMinPrice &&
          matchesMaxPrice;
    }).toList();

    // Sorting.
    filtered.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      final quantityA =
          (dataA['quantity'] as num?)?.toInt() ?? 0;
      final quantityB =
          (dataB['quantity'] as num?)?.toInt() ?? 0;

      final priceA =
          (dataA['unitPrice'] as num?)?.toDouble() ?? 0;
      final priceB =
          (dataB['unitPrice'] as num?)?.toDouble() ?? 0;

      final nameA =
      (dataA['itemName'] ?? '').toString().toLowerCase();
      final nameB =
      (dataB['itemName'] ?? '').toString().toLowerCase();

      switch (sortMode) {
        case 'quantityAsc':
          return quantityA.compareTo(quantityB);

        case 'quantityDesc':
          return quantityB.compareTo(quantityA);

        case 'priceAsc':
          return priceA.compareTo(priceB);

        case 'priceDesc':
          return priceB.compareTo(priceA);

        case 'nameAsc':
          return nameA.compareTo(nameB);

        default:
          return quantityA.compareTo(quantityB);
      }
    });

    return filtered;
  }

  int calculateTotalUnits(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    return docs.fold<int>(0, (total, doc) {
      return total +
          ((doc.data()['quantity'] as num?)?.toInt() ?? 0);
    });
  }

  int calculateLowStock(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    return docs.where((doc) {
      final data = doc.data();

      final quantity =
          (data['quantity'] as num?)?.toInt() ?? 0;
      final reorder =
          (data['reorderLevel'] as num?)?.toInt() ?? 0;

      return quantity <= reorder;
    }).length;
  }

  // ==========================================================
  // DASHBOARD UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined),
            SizedBox(width: 10),
            Text(
              'Stock Inventory',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh inventory',
            onPressed: refreshInventory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddStockPage,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Stock'),
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: inventoryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load inventory',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: refreshInventory,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final documents = snapshot.data?.docs ?? [];
          final filteredItems = filterItems(documents);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            children: [
              // Dashboard heading.
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Manage and monitor your stock inventory.',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // Statistics cards.
              Row(
                children: [
                  Expanded(
                    child: statCard(
                      'Products',
                      '${documents.length}',
                      Icons.inventory_2,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: statCard(
                      'Total Units',
                      '${calculateTotalUnits(documents)}',
                      Icons.warehouse,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: statCard(
                      'Low Stock',
                      '${calculateLowStock(documents)}',
                      Icons.warning_amber,
                      Colors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // =================================================
              // QUICK SEARCH
              // =================================================

              const Text(
                'Search Inventory',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by SKU or item name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                    onPressed: () {
                      setState(() {
                        searchController.clear();
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // =================================================
              // CATEGORY FILTER
              // =================================================

              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  'All',
                  ...stockCategories,
                ].map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value ?? 'All';
                  });
                },
              ),

              const SizedBox(height: 12),

              // =================================================
              // ADVANCED SEARCH PANEL
              // =================================================

              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: Color(0xFFE0E5ED),
                  ),
                ),
                child: ExpansionTile(
                  initiallyExpanded: advancedSearchExpanded,
                  onExpansionChanged: (value) {
                    setState(() {
                      advancedSearchExpanded = value;
                    });
                  },
                  leading: const Icon(
                    Icons.tune,
                    color: Color(0xFF2563EB),
                  ),
                  title: const Text(
                    'Advanced Search & Filters',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Filter by quantity and price range',
                    style: TextStyle(fontSize: 12),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    16, 0, 16, 16,
                  ),
                  children: [
                    const Divider(),

                    // Low stock.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Show low-stock items only',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Quantity ≤ reorder level',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: lowStockOnly,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (value) {
                        setState(() {
                          lowStockOnly = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Quantity range.
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quantity Range',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minQuantityController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Minimum quantity',
                              hintText: 'e.g. 1',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: maxQuantityController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Maximum quantity',
                              hintText: 'e.g. 100',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Price range.
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Unit Price Range (RM)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minPriceController,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Minimum price',
                              hintText: 'e.g. 5.00',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: maxPriceController,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Maximum price',
                              hintText: 'e.g. 100.00',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Sort.
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Sort Results By',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: sortMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.sort),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'quantityAsc',
                          child: Text('Quantity: Low to High'),
                        ),
                        DropdownMenuItem(
                          value: 'quantityDesc',
                          child: Text('Quantity: High to Low'),
                        ),
                        DropdownMenuItem(
                          value: 'priceAsc',
                          child: Text('Price: Low to High'),
                        ),
                        DropdownMenuItem(
                          value: 'priceDesc',
                          child: Text('Price: High to Low'),
                        ),
                        DropdownMenuItem(
                          value: 'nameAsc',
                          child: Text('Item Name: A to Z'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          sortMode = value ?? 'quantityAsc';
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Clear advanced filters.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: clearAllFilters,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset All Filters'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // RESULTS
              // =================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inventory Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filteredItems.length} result(s)',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (filteredItems.isEmpty)
                emptyState(),

              ...filteredItems.map((document) {
                return inventoryCard(document);
              }),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================
  // STATISTICS CARD
  // ==========================================================

  Widget statCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EMPTY STATE
  // ==========================================================

  Widget emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 55,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'No inventory items found',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Try changing your filters or add a new item.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // INVENTORY ITEM CARD
  // ==========================================================

  Widget inventoryCard(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    final sku = (data['sku'] ?? '').toString();
    final name = (data['itemName'] ?? '').toString();
    final category = (data['category'] ?? '').toString();

    final quantity =
        (data['quantity'] as num?)?.toInt() ?? 0;
    final price =
        (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final reorderLevel =
        (data['reorderLevel'] as num?)?.toInt() ?? 0;

    final isLowStock = quantity <= reorderLevel;
    final timestamp = data['createdAt'];

    String createdText = 'Waiting for server timestamp';

    if (timestamp is Timestamp) {
      final date = timestamp.toDate().toLocal();
      createdText =
      '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isLowStock
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLowStock ? 'Low Stock' : 'In Stock',
                    style: TextStyle(
                      color: isLowStock
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 7),

            Text(
              'SKU: $sku',
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Wrap(
              spacing: 20,
              runSpacing: 14,
              children: [
                detailItem('Category', category),
                detailItem('Quantity', '$quantity'),
                detailItem(
                  'Unit Price',
                  'RM ${price.toStringAsFixed(2)}',
                ),
                detailItem('Reorder Level', '$reorderLevel'),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Created: $createdText',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget detailItem(String label, String value) {
    return SizedBox(
      width: 125,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADD STOCK ITEM PAGE
// ============================================================

class AddStockPage extends StatefulWidget {
  const AddStockPage({super.key});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController skuController =
  TextEditingController();
  final TextEditingController nameController =
  TextEditingController();
  final TextEditingController quantityController =
  TextEditingController();
  final TextEditingController priceController =
  TextEditingController();
  final TextEditingController reorderController =
  TextEditingController();

  String? selectedCategory;
  bool isSaving = false;

  final FirebaseFirestore db = FirebaseFirestore.instance;

  @override
  void dispose() {
    skuController.dispose();
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
    reorderController.dispose();
    super.dispose();
  }

  // ==========================================================
  // INTEGER VALIDATION
  // ==========================================================

  String? validateInteger(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final number = int.tryParse(value.trim());

    if (number == null) {
      return '$fieldName must be a whole number';
    }

    if (number < 0) {
      return '$fieldName cannot be negative';
    }

    return null;
  }

  // ==========================================================
  // SKU VALIDATION
  // ==========================================================

  String? validateSku(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'SKU is required';
    }

    if (!RegExp(r'^STK-\d{3}$')
        .hasMatch(value.trim().toUpperCase())) {
      return 'SKU must use format STK- followed by 3 digits';
    }

    return null;
  }

  // ==========================================================
  // ITEM NAME VALIDATION
  // ==========================================================

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Item name is required';
    }

    if (value.trim().length < 3) {
      return 'Item name must have at least 3 characters';
    }

    return null;
  }

  // ==========================================================
  // PRICE VALIDATION
  // ==========================================================

  String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Unit price is required';
    }

    final price = double.tryParse(value.trim());

    if (price == null) {
      return 'Enter a valid unit price';
    }

    if (!price.isFinite || price <= 0) {
      return 'Unit price must be greater than RM 0';
    }

    return null;
  }

  // ==========================================================
  // SAVE STOCK ITEM TO FIRESTORE
  // ==========================================================

  Future<void> saveStockItem() async {
    FocusScope.of(context).unfocus();

    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await db.collection('stockItems').add({
        'sku': skuController.text.trim().toUpperCase(),
        'itemName': nameController.text.trim(),
        'category': selectedCategory,
        'quantity': int.parse(quantityController.text.trim()),
        'unitPrice': double.parse(priceController.text.trim()),
        'reorderLevel': int.parse(reorderController.text.trim()),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock item saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save stock item: $error'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================================
  // FORM UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Stock Item',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Inventory Item',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Fill in the information to add a new stock item.',
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 25),

              // SKU.
              formLabel('SKU'),
              TextFormField(
                controller: skuController,
                enabled: !isSaving,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Example: STK-101',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: validateSku,
              ),

              const SizedBox(height: 18),

              // Item name.
              formLabel('Item Name'),
              TextFormField(
                controller: nameController,
                enabled: !isSaving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Enter item name',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: validateName,
              ),

              const SizedBox(height: 18),

              // Category.
              formLabel('Category'),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Select category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: stockCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: isSaving
                    ? null
                    : (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // Quantity.
              formLabel('Quantity'),
              TextFormField(
                controller: quantityController,
                enabled: !isSaving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter quantity',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) =>
                    validateInteger(value, 'Quantity'),
              ),

              const SizedBox(height: 18),

              // Unit price.
              formLabel('Unit Price (RM)'),
              TextFormField(
                controller: priceController,
                enabled: !isSaving,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: 'Example: 19.90',
                  prefixIcon: Icon(Icons.currency_exchange),
                ),
                validator: validatePrice,
              ),

              const SizedBox(height: 18),

              // Reorder level.
              formLabel('Reorder Level'),
              TextFormField(
                controller: reorderController,
                enabled: !isSaving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter reorder level',
                  prefixIcon: Icon(Icons.warning_amber_outlined),
                ),
                validator: (value) =>
                    validateInteger(value, 'Reorder level'),
              ),

              const SizedBox(height: 30),

              // Save button.
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : saveStockItem,
                  icon: isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isSaving ? 'Saving...' : 'Save Stock Item',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.blueGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel button.
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),

              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  Widget formLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
