import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeSearchRepository implements SearchRepository {
  FakeSearchRepository({this.result});

  Result<List<SearchResult>>? result;
  String? lastQuery;

  @override
  Future<Result<List<SearchResult>>> search(String query) async {
    lastQuery = query;
    return result ?? const Result.ok([]);
  }
}
