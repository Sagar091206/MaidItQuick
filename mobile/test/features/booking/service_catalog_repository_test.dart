import 'package:flutter_test/flutter_test.dart';
import 'package:maiditquick_mobile/core/api_client.dart';
import 'package:maiditquick_mobile/features/booking/data/service_catalog_repository.dart';

class _FakeApi extends ApiClient {
  @override
  Future<dynamic> get(String path, {String? token}) async {
    if (path == '/services/1') {
      return {
        'id': 1,
        'name': 'Bathroom Cleaning',
        'pricePaise': 79900,
        'description': 'Deep cleaning of the bathroom.',
        'emoji': '🛁',
        'defaultDurationMinutes': 60,
        'enabled': true,
      };
    }
    if (path.startsWith('/booking/quote')) {
      return {
        'currency': 'INR',
        'lines': [
          {'name': 'Bathroom Cleaning', 'pricePaise': 79900, 'amountPaise': 159800},
        ],
        'subtotalPaise': 159800,
        'promoCode': 'WELCOME50',
        'discountPaise': 5000,
        'totalPaise': 154800,
      };
    }
    return <String, dynamic>{};
  }
}

void main() {
  test('CatalogService parses the extended details fields', () {
    final service = CatalogService.fromJson(const {
      'id': 1,
      'name': 'Bathroom Cleaning',
      'pricePaise': 79900,
      'enabled': true,
      'description': 'Deep cleaning.',
      'emoji': '🛁',
      'defaultDurationMinutes': 90,
    });
    expect(service.description, 'Deep cleaning.');
    expect(service.emoji, '🛁');
    expect(service.defaultDurationMinutes, 90);
  });

  test('CatalogService tolerates missing detail keys (backward compatible)',
      () {
    final service = CatalogService.fromJson(const {
      'id': 2,
      'name': 'Kitchen Cleaning',
      'pricePaise': 89900,
      'enabled': true,
    });
    expect(service.description, '');
    expect(service.emoji, '');
    expect(service.defaultDurationMinutes, 60);
  });

  test('fetchDetail hits /services/{id}', () async {
    final repo = ServiceCatalogRepository(_FakeApi());
    final detail = await repo.fetchDetail(1);
    expect(detail.id, 1);
    expect(detail.name, 'Bathroom Cleaning');
    expect(detail.emoji, '🛁');
    expect(detail.defaultDurationMinutes, 60);
  });

  test('fetchQuote parses itemised pricing', () async {
    final repo = ServiceCatalogRepository(_FakeApi());
    final quote = await repo.fetchQuote(
      'token',
      services: const ['Bathroom Cleaning'],
      durationMinutes: 120,
      promoCode: 'WELCOME50',
    );
    expect(quote.lines, hasLength(1));
    expect(quote.lines.first.amountPaise, 159800);
    expect(quote.subtotalPaise, 159800);
    expect(quote.discountPaise, 5000);
    expect(quote.totalPaise, 154800);
    expect(quote.promoCode, 'WELCOME50');
  });
}
