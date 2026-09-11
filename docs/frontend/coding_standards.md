# Sugatai Frontend -- Coding Standards

Dart and Flutter rules. Read before writing any frontend code.

---

## 1. Light Theme Only

No dark mode. No `ThemeMode.system`. No conditional color checks. Hardcode light colors.

```dart
// CORRECT
MaterialApp(
  themeMode: ThemeMode.light,
  theme: AppTheme.light,
  // No darkTheme property
);

// WRONG
themeMode: ThemeMode.system,
darkTheme: AppTheme.dark,
```

---

## 2. No Emojis

Never use emoji characters in UI text, placeholder text, comments, or Strings.

```dart
// CORRECT
const emptyText = 'No outfits yet. Generate your first look.';

// WRONG
const emptyText = 'No outfits yet. Generate your first look! ✨';
```

---

## 3. Riverpod State Management

### Provider types

| Use Case | Provider Type |
|---|---|
| Immutable value / config | `Provider` |
| Async data from API | `FutureProvider` / `AsyncNotifierProvider` |
| List that changes over time | `StateNotifierProvider` / `NotifierProvider` |
| Stream (real-time) | `StreamProvider` |
| Simple mutable state | `StateProvider` |

### File pattern

Each feature has a `providers/` folder. One file per provider.

```
features/wardrobe/
  providers/
    wardrobe_provider.dart      # items list + filters
    wardrobe_filter_provider.dart  # filter state
```

### Provider naming

```dart
// Providers end with Provider
final wardrobeProvider = AsyncNotifierProvider<WardrobeNotifier, List<Item>>(WardrobeNotifier.new);
final authStateProvider = StateProvider<AuthState>((ref) => AuthState.initial());

// Notifiers end with Notifier
class WardrobeNotifier extends AsyncNotifier<List<Item>> { ... }
```

### Watching providers

```dart
// In widgets -- use ref.watch for reactive rebuilds
final items = ref.watch(wardrobeProvider);

// For one-time reads (in callbacks)
final api = ref.read(apiClientProvider);

// For side effects
ref.listen(authStateProvider, (prev, next) {
  if (next == AuthState.loggedOut) {
    context.go('/login');
  }
});
```

### Never put business logic in widgets

```dart
// CORRECT -- logic in notifier
class WardrobeNotifier extends AsyncNotifier<List<Item>> {
  Future<void> deleteItem(String id) async {
    await ref.read(apiClientProvider).deleteItem(id);
    state = AsyncValue.data(
      state.value?.where((i) => i.id != id).toList() ?? [],
    );
  }
}

// In widget:
onTap: () => ref.read(wardrobeProvider.notifier).deleteItem(item.id);

// WRONG -- API call in widget
onTap: () async {
  await Dio().delete('/items/$id');
  setState(() { items.removeWhere((i) => i.id == id); });
}
```

---

## 4. GoRouter Navigation

### Route naming

```dart
// Routes are lowercase with underscores
GoRoute(path: '/wardrobe', name: 'wardrobe', ...),
GoRoute(path: '/outfits/today', name: 'today_outfits', ...),
GoRoute(path: '/items/:id', name: 'item_detail', ...),
```

### Navigation calls

```dart
// Named navigation (preferred)
context.goNamed('item_detail', pathParameters: {'id': item.id});

// Simple path
context.go('/wardrobe');

// Push (adds to stack, shows back button)
context.pushNamed('item_detail', pathParameters: {'id': item.id});
```

### Deep links

Every screen must be reachable via URL path for push notification deep linking.

---

## 5. Dio Network Layer

### Single Dio instance via Riverpod

```dart
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Environment.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Auth interceptor
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await ref.read(firebaseTokenProvider.future);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        // Force re-login
        ref.read(authStateProvider.notifier).state = AuthState.loggedOut;
      }
      handler.next(error);
    },
  ));

  return dio;
});
```

### API calls always in repository classes

```dart
class ItemRepository {
  final Dio _dio;
  ItemRepository(this._dio);

  Future<List<Item>> getItems({String? category, String? color}) async {
    final response = await _dio.get('/items', queryParameters: {
      if (category != null) 'category': category,
      if (color != null) 'color': color,
    });
    final data = response.data['items'] as List;
    return data.map((json) => Item.fromJson(json)).toList();
  }

  Future<Item> uploadItem(File imageFile) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imageFile.path),
    });
    final response = await _dio.post('/items/upload', data: formData);
    return Item.fromJson(response.data);
  }
}
```

---

## 6. Loading + Error + Empty States

Every screen that loads data must handle all three states. No blank screens.

```dart
// Using AsyncValue from Riverpod
items.when(
  loading: () => const ItemsLoadingSkeleton(),
  error: (e, _) => ErrorView(
    message: 'Could not load wardrobe',
    onRetry: () => ref.invalidate(wardrobeProvider),
  ),
  data: (itemList) => itemList.isEmpty
    ? const EmptyWardrobeView()  // illustration + CTA
    : WardrobeGrid(items: itemList),
);
```

### Skeleton loading pattern

```dart
class ItemsLoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
```

### Error view pattern

```dart
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: AppTypography.body),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
```

---

## 7. Single Responsibility

- Max widget build method: ~50 lines. Extract sub-widgets if longer.
- Max file length: ~300 lines.
- One widget per file (except tiny private helpers).
- Feature-based folder structure: `features/{name}/presentation/`, `features/{name}/data/`, `features/{name}/providers/`.

---

## 8. Naming Conventions

| What | Pattern | Example |
|---|---|---|
| Files | `snake_case.dart` | `wardrobe_screen.dart` |
| Classes | `PascalCase` | `WardrobeScreen` |
| Functions | `camelCase` | `fetchItems()` |
| Variables | `camelCase` | `itemCount` |
| Constants | `camelCase` (Dart convention) | `defaultPadding` |
| Providers | `camelCaseProvider` | `wardrobeProvider` |
| Notifiers | `PascalCaseNotifier` | `WardrobeNotifier` |
| Repositories | `PascalCaseRepository` | `ItemRepository` |
| Models | `PascalCase` | `Item`, `OutfitResponse` |
| Enums | `PascalCase` + `camelCase` values | `ItemCategory.top` |
| Routes | `camelCase` | `itemDetail` |
| Assets | `snake_case` | `empty_wardrobe.svg` |

---

## 9. Image Handling

### Always use `cached_network_image`

```dart
CachedNetworkImage(
  imageUrl: item.imageUrl,
  placeholder: (_, __) => Container(color: AppColors.gray100),
  errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
  fit: BoxFit.cover,
)
```

### Never load full-size images in grids

Use thumbnail URLs for grid views. Load full-size only on detail screens.

---

## 10. Spacing and Layout

### Use the 4px grid

```dart
// CORRECT -- multiples of 4
const EdgeInsets.all(16)
const SizedBox(height: 8)
const EdgeInsets.symmetric(horizontal: 20, vertical: 12)

// WRONG -- arbitrary values
const EdgeInsets.all(15)
const SizedBox(height: 7)
```

### Consistent screen padding

```dart
// Every screen body wraps in:
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: ...
)
```

---

## 11. No Gradients, No Shadows (Almost)

Flat design with borders. Only elevation:

- Cards: 1px border, `AppColors.gray200`
- Modals/bottom sheets: subtle shadow (`elevation: 4`)
- FAB: standard Material elevation
- Everything else: flat

```dart
// CORRECT
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: AppColors.gray200),
    borderRadius: BorderRadius.circular(12),
  ),
)

// WRONG
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(...),
    boxShadow: [BoxShadow(...)],
  ),
)
```

---

## 12. Font: Inter Only

```dart
// In theme
textTheme: GoogleFonts.interTextTheme()

// Never use other fonts. Never use system default.
```

Typography scale (from design system):

| Style | Size | Weight | Use |
|---|---|---|---|
| Display | 28px | Bold | Screen titles |
| Heading | 22px | SemiBold | Section headers |
| Title | 18px | SemiBold | Card titles |
| Body | 16px | Regular | Default text |
| Label | 14px | Medium | Buttons, labels |
| Caption | 12px | Regular | Timestamps, hints |
| Chip | 13px | Medium | Tag chips |

---

## 13. Testing

### Widget tests for every screen

```dart
testWidgets('Wardrobe grid shows items', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wardrobeProvider.overrideWith(() => FakeWardrobeNotifier(mockItems)),
      ],
      child: const MaterialApp(home: WardrobeScreen()),
    ),
  );

  expect(find.byType(ItemCard), findsNWidgets(3));
});
```

### Mock all API calls in tests

Never make real HTTP requests in widget tests.

---

## 14. Git Conventions

```
feat: add wardrobe grid screen
fix: handle empty state in today's outfits
chore: bump riverpod to 2.5
ui: adjust spacing in onboarding quiz
test: add widget tests for camera screen
```

One feature per PR. All tests pass before merge. Squash merge to main.

---

## 15. Accessibility

- All images have `semanticsLabel`
- All interactive elements have minimum 48x48 tap target
- Text scales with system font size (use `MediaQuery.textScaleFactor`)
- Sufficient color contrast (4.5:1 for body text)
