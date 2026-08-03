# US-06 — Booking Summary & Itemised Pricing (Quote API)

> Master prompt: `00_MASTER_SYSTEM_PROMPT.md`. Prerequisites: US-05.
> Backend: **modify 1 file** (`BookingPlanningController.java`). Flutter: **modify 2 files** (`service_catalog_repository.dart`, `booking_wizard_screen.dart`).

## 1. Objective

Provide a server-authoritative, itemised price quote for the booking summary step:

- **Pricing rule:** each selected task contributes `pricePaise × (durationMinutes / 60)` (minimum 1 hour per task). Subtotal = sum of line items. Discount comes from a validated promo code. Total = subtotal − discount.
- The summary step in the wizard (US-05) replaces its local estimate with this quote and adds a promo-code field validated against `POST /api/customer/promos/validate`.

## 2. API contract (new)

### `GET /api/booking/quote?services=Bathroom%20Cleaning,Kitchen%20Cleaning&durationMinutes=120&promoCode=WELCOME50`

**Auth:** customer (Bearer token). **Response 200:**

```json
{
  "currency": "INR",
  "lines": [
    { "name": "Bathroom Cleaning", "pricePaise": 79900, "amountPaise": 159800 },
    { "name": "Kitchen Cleaning", "pricePaise": 99900, "amountPaise": 199800 }
  ],
  "subtotalPaise": 359600,
  "promoCode": "WELCOME50",
  "discountPaise": 5000,
  "totalPaise": 354600
}
```

**Errors:** `400` invalid duration/promo; `401` missing session. `promoCode` optional.

## 3. Backend implementation

Modify `server/src/main/java/com/makeitquick/booking/BookingPlanningController.java`:

```java
import com.makeitquick.catalog.ServiceItemRepository;
import com.makeitquick.catalog.ServiceItem;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import java.util.LinkedHashMap;
import java.util.Optional;

@RestController
@RequestMapping("/api/booking")
@CrossOrigin(origins = "*")
public class BookingPlanningController {
    // ...existing SLOTS list and slots()/calculateDuration() unchanged...

    private final ServiceItemRepository services;
    private final SessionResolver resolver;

    BookingPlanningController(ServiceItemRepository services, SessionResolver resolver) {
        this.services = services;
        this.resolver = resolver;
    }

    @GetMapping("/quote")
    public Map<String, Object> quote(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam List<String> servicesParam,
            @RequestParam @Min(30) @Max(480) int durationMinutes,
            @RequestParam(required = false) String promoCode) {
        requireCustomer(authorization);
        List<String> names = servicesParam.stream()
                .map(String::trim).filter(s -> !s.isBlank()).distinct().toList();
        if (names.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Choose at least one service");
        }
        double hours = Math.max(1.0, durationMinutes / 60.0);
        List<Map<String, Object>> lines = new ArrayList<>();
        long subtotal = 0;
        for (String name : names) {
            ServiceItem item = services.findByEnabledTrueAndNameIgnoreCase(name)
                    .orElseThrow(() -> new ResponseStatusException(
                            HttpStatus.BAD_REQUEST, name + " is not available"));
            long amount = Math.round(item.getPricePaise() * hours);
            subtotal += amount;
            lines.add(Map.of(
                    "name", item.getName(),
                    "pricePaise", item.getPricePaise(),
                    "amountPaise", amount));
        }
        int discount = promoDiscount(promoCode);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("currency", "INR");
        result.put("lines", lines);
        result.put("subtotalPaise", subtotal);
        result.put("promoCode", promoCode == null ? "" : promoCode.toUpperCase());
        result.put("discountPaise", discount);
        result.put("totalPaise", Math.max(0, subtotal - discount));
        return result;
    }

    private int promoDiscount(String code) {
        if (code == null || code.isBlank()) return 0;
        return switch (code.trim().toUpperCase()) {
            case "WELCOME50" -> 5000;
            case "MAKEITQUICK100" -> 10000;
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Promo code is invalid");
        };
    }

    private void requireCustomer(String authorization) {
        UserAccount user = resolver.fromBearer(authorization)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (user.getRole() != Role.CUSTOMER) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Customer access required");
        }
    }
}
```

> Note: `calculateDuration()` currently computes `count × 60` minutes. Optionally align it with task `defaultDurationMinutes` from US-04 (`Σ defaultDurationMinutes`, min 30) so the quote and duration stay consistent. Keep the old formula if you prefer — the quote API only consumes the duration passed by the client.

Add to `ServiceItemRepository`:

```java
Optional<ServiceItem> findByEnabledTrueAndNameIgnoreCase(String name);
```

## 4. Flutter implementation

### 4.1 Quote model + fetch (modify `service_catalog_repository.dart`)

```dart
  /// Server-authoritative itemised quote for the selected services.
  Future<BookingQuote> fetchQuote(
    String token, {
    required List<String> services,
    required int durationMinutes,
    String promoCode = '',
  }) async {
    final query = StringBuffer('/booking/quote?durationMinutes=$durationMinutes');
    for (final service in services) {
      query.write('&services=${Uri.encodeQueryComponent(service)}');
    }
    if (promoCode.trim().isNotEmpty) {
      query.write('&promoCode=${Uri.encodeQueryComponent(promoCode.trim())}');
    }
    final payload =
        Map<String, dynamic>.from(await _api.get(query.toString(), token: token) as Map);
    return BookingQuote.fromJson(payload);
  }
```

New model (same file, after `AvailabilityStatus`):

```dart
class BookingQuote {
  const BookingQuote({
    required this.currency,
    required this.lines,
    required this.subtotalPaise,
    required this.promoCode,
    required this.discountPaise,
    required this.totalPaise,
  });

  factory BookingQuote.fromJson(Map<String, dynamic> json) => BookingQuote(
        currency: json['currency'] as String? ?? 'INR',
        lines: (json['lines'] as List? ?? const [])
            .map((item) =>
                QuoteLine.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        subtotalPaise: (json['subtotalPaise'] as num?)?.toInt() ?? 0,
        promoCode: json['promoCode'] as String? ?? '',
        discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
        totalPaise: (json['totalPaise'] as num?)?.toInt() ?? 0,
      );

  final String currency;
  final List<QuoteLine> lines;
  final int subtotalPaise;
  final String promoCode;
  final int discountPaise;
  final int totalPaise;
}

class QuoteLine {
  const QuoteLine({
    required this.name,
    required this.pricePaise,
    required this.amountPaise,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
        name: json['name'] as String? ?? '',
        pricePaise: (json['pricePaise'] as num?)?.toInt() ?? 0,
        amountPaise: (json['amountPaise'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final int pricePaise;
  final int amountPaise;
}
```

### 4.2 Wizard summary step uses the quote (modify `booking_wizard_screen.dart`)

Add state:

```dart
  BookingQuote? _quote;
  bool _quoteLoading = false;
  final _promo = TextEditingController();
```

Dispose `_promo` alongside the other controllers.

Fetch when entering the summary step — call inside `_next()` when `next == 3`, and also after promo apply:

```dart
  Future<void> _loadQuote() async {
    if (_selected.isEmpty) return;
    setState(() => _quoteLoading = true);
    try {
      final quote = await ServiceCatalogRepository(widget.api).fetchQuote(
        widget.session.token,
        services: _selectedNames,
        durationMinutes: _durationMinutes,
        promoCode: _promo.text.trim(),
      );
      if (mounted) setState(() => _quote = quote);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _applyPromo() async {
    await _loadQuote();
  }
```

Replace the estimate card inside `_buildSummaryStep()`:

```dart
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _quoteLoading
                ? const SkeletonBox(width: double.infinity, height: 120)
                : _quote == null
                    ? OutlinedButton.icon(
                        onPressed: _loadQuote,
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Load price estimate'),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in _quote!.lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: Text(line.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700))),
                                  Text(formatPaise(line.amountPaise)),
                                ],
                              ),
                            ),
                          const Divider(),
                          _PriceRow(label: 'Subtotal', value: _quote!.subtotalPaise),
                          if (_quote!.discountPaise > 0)
                            _PriceRow(
                              label: 'Discount (${_quote!.promoCode})',
                              value: -_quote!.discountPaise,
                            ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                              Text(formatPaise(_quote!.totalPaise),
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _promo,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Promo code (optional)',
            hintText: 'WELCOME50',
            prefixIcon: Icon(Icons.local_offer_outlined),
          ),
          onSubmitted: (_) => _applyPromo(),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _quoteLoading ? null : _applyPromo,
          icon: const Icon(Icons.bolt_outlined),
          label: Text(_quoteLoading ? 'Applying…' : 'Apply promo'),
        ),
```

Add the small helper widget at the bottom of the file:

```dart
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final display = value < 0 ? '-${formatPaise(-value)}' : formatPaise(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.brandMuted)),
          Text(display, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
```

Keep `_estimateTotal()` as a fallback shown only while `_quote == null`.

## 5. UI states checklist

- Quote loading → `SkeletonBox` card.
- Quote error → snackbar with the server message + "Load price estimate" retry.
- Empty (no services) → quote card hidden.
- Success → itemised lines, subtotal, discount, total.

## 6. Tests

Backend test (`server/src/test/java/.../BookingPlanningControllerTest.java`):

```java
@Test
void quoteComputesItemisedTotals() throws Exception {
    String token = obtainCustomerToken(); // reuse the existing auth test helper
    mvc.perform(get("/api/booking/quote")
            .param("services", "Bathroom Cleaning", "Kitchen Cleaning")
            .param("durationMinutes", "120")
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.lines.length()").value(2))
        .andExpect(jsonPath("$.totalPaise").isNumber());
}

@Test
void quoteRejectsInvalidPromo() throws Exception {
    mvc.perform(get("/api/booking/quote")
            .param("services", "Bathroom Cleaning")
            .param("durationMinutes", "60")
            .param("promoCode", "NOPE")
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isBadRequest());
}
```

Flutter: unit test for `BookingQuote.fromJson` and `fetchQuote` with a fake `ApiClient`.

## 7. Verification

```
cd D:\MaidItQuick\server
mvn -q compile && mvn test

cd D:\MaidItQuick\mobile
flutter analyze && flutter test
```

## 8. Acceptance criteria

- [ ] `GET /api/booking/quote` returns itemised pricing; duration-based.
- [ ] Invalid promo → 400; unknown service → 400; unauthenticated → 401.
- [ ] Wizard summary shows the server quote with subtotal/discount/total.
- [ ] Promo field validates and re-quotes.
- [ ] `POST /api/bookings` (US-07) will use the same pricing for the payment amount.
