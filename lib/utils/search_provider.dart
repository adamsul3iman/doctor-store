import 'package:flutter_riverpod/flutter_riverpod.dart';

// هذا المزود يحمل نص البحث الحالي
final searchQueryProvider = StateProvider<String>((ref) => "");