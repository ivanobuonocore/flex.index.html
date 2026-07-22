import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeCalendarSyncRepository implements CalendarSyncRepository {
  FakeCalendarSyncRepository({
    this.fetchStatusResult,
    this.beginConnectResult,
    this.disconnectResult,
  });

  Result<CalendarConnection?>? fetchStatusResult;
  Result<Unit>? beginConnectResult;
  Result<Unit>? disconnectResult;
  int beginConnectCallCount = 0;
  int disconnectCallCount = 0;

  @override
  Future<Result<CalendarConnection?>> fetchConnectionStatus() async {
    return fetchStatusResult ?? const Result.ok(null);
  }

  @override
  Future<Result<Unit>> beginConnect() async {
    beginConnectCallCount += 1;
    return beginConnectResult ?? const Result.ok(unit);
  }

  @override
  Future<Result<Unit>> disconnect() async {
    disconnectCallCount += 1;
    return disconnectResult ?? const Result.ok(unit);
  }
}
