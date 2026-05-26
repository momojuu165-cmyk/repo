import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/item.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../utils/image_helper.dart';
import 'product_request_screen.dart';

class ProductBrowseScreen extends StatefulWidget {
  const ProductBrowseScreen({super.key});

  @override
  State<ProductBrowseScreen> createState() => _ProductBrowseScreenState();
}

class _ProductBrowseScreenState extends State<ProductBrowseScreen> {
  String _query = '';
  int? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final inv = context.watch<InventoryProvider>();
    final auth = context.watch<AuthProvider>();
    final priceType =
        auth.currentCustomer?.priceType ?? AppConstants.priceRetail;

    final items = inv.items
        .where((item) =>
            !item.isBlocked &&
            item.quantity > 0 &&
            (_query.isEmpty ||
                item.name.contains(_query) ||
                (item.barcode?.contains(_query) ?? false)) &&
            (_selectedGroupId == null ||
                item.groupId == _selectedGroupId))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث عن منتج...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (inv.groups.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: inv.groups.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: FilterChip(
                      label: const Text('الكل'),
                      selected: _selectedGroupId == null,
                      onSelected: (_) =>
                          setState(() => _selectedGroupId = null),
                    ),
                  );
                }
                final g = inv.groups[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: FilterChip(
                    label: Text(g.name),
                    selected: _selectedGroupId == g.id,
                    onSelected: (_) =>
                        setState(() => _selectedGroupId = g.id),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('لا توجد منتجات'))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _ProductCard(
                    item: items[i],
                    priceType: priceType,
                    onTap: () => _openRequestSheet(ctx, items[i]),
                  ),
                ),
        ),
      ],
    );
  }

  void _openRequestSheet(BuildContext context, Item item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductRequestScreen(item: item),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Item item;
  final String priceType;
  final VoidCallback onTap;

  const _ProductCard({
    required this.item,
    required this.priceType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: buildProductImage(
                    item.imagePath,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fallback: _PlaceholderImage(item: item),
                  ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppFormatters.formatCurrency(
                        item.priceForType(priceType)),
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  if (item.quantity <= 10)
                    Text(
                      'متبقي: ${item.quantity.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  final Item item;

  const _PlaceholderImage({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(AppColors.primaryInt).withValues(alpha: 0.05),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
            const SizedBox(height: 4),
            Text(
              item.name[0],
              style: const TextStyle(
                  fontSize: 28,
                  color: Color(AppColors.primaryInt),
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
