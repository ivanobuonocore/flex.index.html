import 'package:pip_shared/pip_shared.dart';

import '../entities/search_result.dart';

/// Confine verso la Ricerca Universale, implementato nel layer `data` di
/// ogni app (Dependency Inversion — Engineering Constitution, Articolo 4).
/// A differenza degli altri repository non espone uno `Stream`: la ricerca è
/// on-demand, non un dato da osservare in tempo reale.
abstract interface class SearchRepository {
  Future<Result<List<SearchResult>>> search(String query);
}
