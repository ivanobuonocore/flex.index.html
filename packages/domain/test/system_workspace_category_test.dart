import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  test('SystemWorkspaceCategory.all elenca le 4 sezioni fisse, senza duplicati',
      () {
    expect(SystemWorkspaceCategory.all, [
      SystemWorkspaceCategory.bilancio,
      SystemWorkspaceCategory.appuntamenti,
      SystemWorkspaceCategory.attivita,
      SystemWorkspaceCategory.documenti,
    ]);
    expect(SystemWorkspaceCategory.all.toSet().length,
        SystemWorkspaceCategory.all.length);
  });
}
