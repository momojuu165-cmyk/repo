import 'package:flutter_test/flutter_test.dart';
import 'package:store_management/models/customer_invoice.dart';

void main() {
  test('CustomerInvoice serializes its store type for new invoices', () {
    final invoice = CustomerInvoice(
      customerId: 18,
      invoiceNo: 'INV-202605-0005',
      total: 8000,
      paymentMethod: 'in_store',
      status: 'pending',
      date: '2026-05-25',
      createdAt: '2026-05-25T02:49:57.535',
      customerStoreType: 'electrical',
    );

    expect(invoice.toMap()['store_type'], 'electrical');
  });
}
