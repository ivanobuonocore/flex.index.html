import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../core/providers.dart';

/// Risultati della Ricerca Universale per la query corrente. A differenza
/// delle altre feature non è uno `StreamProvider`: la ricerca è on-demand
/// (`search`), non un dato da osservare in tempo reale.
final searchControllerProvider =
    AsyncNotifierProvider.autoDispose<SearchController, List<SearchResult>>(
  SearchController.new,
);

class SearchController extends AutoDisposeAsyncNotifier<List<SearchResult>> {
  @override
  Future<List<SearchResult>> build() async => const [];

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    final result = await ref.read(searchRepositoryProvider).search(query);
    state = result.fold(
      (results) => AsyncData(results),
      (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}
