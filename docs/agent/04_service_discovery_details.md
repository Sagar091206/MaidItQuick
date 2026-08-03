# US-04 — Service Discovery & Service Details

> Master prompt: `00_MASTER_SYSTEM_PROMPT.md`. Prerequisites: US-01, US-03.
> Files touched: **2 backend**, **1 migration**, **2 Flutter data**, **2 Flutter presentation**, plus small wiring in `mvp_home_screen.dart` (grid tap → details).

## 1. Objective

Add a full service-details experience: each catalog item gains a description, an emoji, and a default duration; a new `GET /api/services/{id}` endpoint returns the details; the dashboard grid opens a premium `ServiceDetailsScreen` with a **Book this service** CTA that pre-selects the service in the booking flow.

## 2. Scope

- **In:** catalog extension (backend + DB), details screen, dashboard wiring.
- **Out:** no changes to service pricing logic, admin endpoints (`/api/services/admin`, `POST /api/services`), or the availability check.

## 3. Tech stack details

- Backend: Spring Boot, JPA entity `ServiceItem` (`com.makeitquick.catalog`), record DTO, `CatalogController`.
- DB: guarded `ALTER TABLE` migration in `server/db/manual/` (house style).
- Flutter: extend `CatalogService` model; new `ServiceDetailsScreen`; route from dashboard grid and search.

## 4. Database migration (new file)

`server/db/manual/2026-08-02-service-details.sql`

```sql
-- Service details: description, emoji and default duration for the customer
-- service-details screen. Run once on existing databases; fresh databases get
-- these columns from the ServiceItem entity via Hibernate.

SET @description_col := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_catalog' AND COLUMN_NAME = 'description');
SET @sql1 := IF(@description_col = 0,
    'ALTER TABLE service_catalog ADD COLUMN description TEXT NULL',
    'SELECT 1');
PREPARE stmt1 FROM @sql1; EXECUTE stmt1; DEALLOCATE PREPARE stmt1;

SET @emoji_col := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_catalog' AND COLUMN_NAME = 'emoji');
SET @sql2 := IF(@emoji_col = 0,
    "ALTER TABLE service_catalog ADD COLUMN emoji VARCHAR(8) NULL",
    'SELECT 1');
PREPARE stmt2 FROM @sql2; EXECUTE stmt2; DEALLOCATE PREPARE stmt2;

SET @duration_col := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'service_catalog' AND COLUMN_NAME = 'default_duration_minutes');
SET @sql3 := IF(@duration_col = 0,
    'ALTER TABLE service_catalog ADD COLUMN default_duration_minutes INT NOT NULL DEFAULT 60',
    'SELECT 1');
PREPARE stmt3 FROM @sql3; EXECUTE stmt3; DEALLOCATE PREPARE stmt3;
```

> Verify column names against the live schema first (`SHOW COLUMNS FROM service_catalog;` — Hibernate may have created `price_paise`, `enabled`, etc. Adjust the `ALTER` accordingly; the guard pattern is what matters).

## 5. Backend implementation

### 5.1 Extend `ServiceItem.java` (modify)

Add fields and accessors (entity style matches the existing compact file):

```java
@Column(length = 1000) private String description = "";
@Column(length = 8) private String emoji = "";
@Column(nullable = false) private int defaultDurationMinutes = 60;

public String getDescription() { return description == null ? "" : description; }
public String getEmoji() { return emoji == null ? "" : emoji; }
public int getDefaultDurationMinutes() { return defaultDurationMinutes; }
```

### 5.2 New repository method (modify `ServiceItemRepository.java`)

```java
Optional<ServiceItem> findByIdAndEnabledTrue(Long id);
```

### 5.3 `CatalogController.java` (modify)

Add a details view + endpoint. Keep the existing list response backward compatible by **adding** keys:

```java
@GetMapping("/{id}")
public Map<String, Object> detail(@PathVariable Long id) {
    ServiceItem service = services.findByIdAndEnabledTrue(id)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service not found"));
    return serviceView(service);
}

private Map<String, Object> serviceView(ServiceItem service) {
    Map<String, Object> view = new LinkedHashMap<>();
    view.put("id", service.getId());
    view.put("name", service.getName());
    view.put("pricePaise", service.getPricePaise());
    view.put("description", service.getDescription());
    view.put("emoji", service.getEmoji());
    view.put("defaultDurationMinutes", service.getDefaultDurationMinutes());
    view.put("enabled", service.isEnabled());
    return view;
}
```

Update the two `list(...)` methods to return `serviceView(service)` maps instead of raw entities (additive keys, so `ServiceCategory.fromJson` still works). Add `import java.util.LinkedHashMap;`.

### 5.4 Seed descriptions (optional but recommended)

Add a guarded seed block at the end of the migration:

```sql
UPDATE service_catalog SET emoji = '🛁', description = 'Deep cleaning of sinks, taps, mirrors, tiles and WC with the customer-provided supplies.'
WHERE emoji IS NULL OR emoji = '' AND name LIKE '%bath%';
```

Keep it minimal — one UPDATE per known service name family, all `WHERE ... = ''` guarded so it only runs once.

## 6. Flutter implementation

### 6.1 Extend `CatalogService` (modify `features/booking/data/service_catalog_repository.dart`)

```dart
class CatalogService {
  const CatalogService({
    required this.id,
    required this.name,
    required this.pricePaise,
    required this.enabled,
    this.description = '',
    this.emoji = '',
    this.defaultDurationMinutes = 60,
  });

  factory CatalogService.fromJson(Map<String, dynamic> json) => CatalogService(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        pricePaise: (json['pricePaise'] as num).toInt(),
        enabled: json['enabled'] as bool? ?? true,
        description: json['description'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        defaultDurationMinutes:
            (json['defaultDurationMinutes'] as num?)?.toInt() ?? 60,
      );

  final int id;
  final String name;
  final int pricePaise;
  final bool enabled;
  final String description;
  final String emoji;
  final int defaultDurationMinutes;

  String get priceLabel => 'From ₹${(pricePaise / 100).round()}';
}
```

Add a detail fetch method:

```dart
  /// Fetches a single enabled service with its full details.
  Future<CatalogService> fetchDetail(int id) async {
    final payload = Map<String, dynamic>.from(
        await _api.get('/services/$id') as Map);
    return CatalogService.fromJson(payload);
  }
```

### 6.2 New file: `features/services/presentation/service_details_screen.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../booking/data/service_catalog_repository.dart';
import '../../booking/presentation/booking_wizard_screen.dart';

/// Premium service details screen opened from the dashboard grid.
class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({
    super.key,
    required this.api,
    required this.session,
    required this.serviceId,
    required this.initialService,
    required this.onLogout,
  });

  final ApiClient api;
  final Session session;
  final int serviceId;
  final CatalogService initialService;
  final VoidCallback onLogout;

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  CatalogService? _service;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ServiceCatalogRepository(widget.api)
          .fetchDetail(widget.serviceId);
      if (mounted) setState(() => _service = detail);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this service.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _bookThisService() {
    final service = _service ?? widget.initialService;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingWizardScreen(
          api: widget.api,
          session: widget.session,
          onLogout: widget.onLogout,
          initialServices: [service.name],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final service = _service;
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Service' : service?.name ?? 'Service'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const SkeletonListView(itemCount: 3)
            : _error != null
                ? ErrorStateView(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        color: context.brandCard,
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Text(
                                service!.emoji.isEmpty
                                    ? '🧽'
                                    : service.emoji,
                                style: const TextStyle(fontSize: 56),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                service.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                service.priceLabel,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(title: "What's included"),
                      const SizedBox(height: 8),
                      Card(
                        color: context.brandCard,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            service.description.isEmpty
                                ? 'Professional ${service.name.toLowerCase()} using the supplies you provide at your home.'
                                : service.description,
                            style: TextStyle(
                              color: context.brandMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(title: 'Good to know'),
                      const SizedBox(height: 8),
                      Card(
                        color: context.brandCard,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _InfoRow(
                                icon: Icons.timer_outlined,
                                text:
                                    'Typical duration: ${service.defaultDurationMinutes} minutes',
                              ),
                              const SizedBox(height: 10),
                              const _InfoRow(
                                icon: Icons.cleaning_services_outlined,
                                text: 'You provide the cleaning supplies',
                              ),
                              const SizedBox(height: 10),
                              const _InfoRow(
                                icon: Icons.group_outlined,
                                text: 'A verified partner is assigned automatically',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _bookThisService,
                        icon: const Icon(Icons.add_task_outlined),
                        label: Text('Book ${service.name}'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: context.brandMuted)),
        ),
      ],
    );
  }
}
```

> `BookingWizardScreen` ships in US-05. Until then this screen won't compile. **Implementation order:** build US-05's `BookingWizardScreen` (even a minimal compileable version) before wiring the CTA, or temporarily comment the `_bookThisService` navigation and restore it after US-05. The story order expects you to complete US-04 and US-05 before running `flutter analyze` together.

### 6.3 Dashboard wiring (modify `mvp_home_screen.dart`)

- `_ServiceCard` gains `onTap` that pushes `ServiceDetailsScreen` instead of starting the booking flow directly:

```dart
  Future<void> _openServiceDetails(ServiceCategory service) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ServiceDetailsScreen(
          api: widget.api,
          session: widget.session,
          serviceId: service.id,
          initialService: CatalogService(
            id: service.id,
            name: service.name,
            pricePaise: service.pricePaise,
            enabled: true,
          ),
          onLogout: widget.onLogout,
        ),
      ),
    );
  }
```

- Pass `onTap: () => _openServiceDetails(services[index])` from the grid.

## 7. UI states checklist

- Loading → `SkeletonListView`.
- Error/retry → `ErrorStateView`.
- Empty description → fallback copy.
- Success → details card + CTA.
- Pull-to-refresh → refresh IconButton in the app bar.

## 8. Tests

Backend (`server/src/test/java/com/makeitquick/catalog/CatalogControllerTest.java` if a test skeleton exists, otherwise extend the existing test class):

```java
@SpringBootTest
@AutoConfigureMockMvc
class CatalogControllerDetailsTest {
    @Autowired MockMvc mvc;

    @Test
    void detailsReturnsDescriptionAndEmoji() throws Exception {
        mvc.perform(get("/api/services/1"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.name").exists())
           .andExpect(jsonPath("$.pricePaise").exists());
    }

    @Test
    void unknownServiceIs404() throws Exception {
        mvc.perform(get("/api/services/999999"))
           .andExpect(status().isNotFound());
    }
}
```

Flutter: extend the catalog repository test to cover `fetchDetail` with a fake `ApiClient`; widget test for `ServiceDetailsScreen` loading → content.

## 9. Verification

```
cd D:\MaidItQuick\server
mvn -q compile && mvn test

cd D:\MaidItQuick\mobile
flutter analyze
flutter test
```

## 10. Acceptance criteria

- [ ] `GET /api/services/{id}` returns description/emoji/defaultDurationMinutes.
- [ ] Dashboard grid opens service details; Book CTA pre-selects the service.
- [ ] List endpoint remains backward compatible (old keys unchanged).
- [ ] Migration is guarded and idempotent.
