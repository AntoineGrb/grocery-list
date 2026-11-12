import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/features/liste/ui/add_sheet.dart';
import 'package:kadi/features/liste/ui/add_sheet_rows.dart';

/// Tag ⚡ Fréquents du Panneau + ouvert.
Finder get frequentsTag => find.descendant(
  of: find.byType(AddSheet),
  matching: find.bySemanticsLabel(StringsFr.frequents),
);

/// Touche ⚡ Fréquents : le clavier se ferme, les fréquents s'affichent en
/// pastilles (V2 2g). Sans effet s'ils le sont déjà.
Future<void> showFrequents(WidgetTester tester) async {
  if (find.text(StringsFr.ajoutsFrequents).evaluate().isNotEmpty ||
      find.byType(FrequentChip).evaluate().isNotEmpty) {
    return;
  }
  final tag = find.descendant(
    of: find.byType(AddSheet),
    matching: find.text(StringsFr.frequents),
  );
  // La rangée des tags défile : le tag est d'abord amené à l'écran.
  await tester.ensureVisible(tag);
  await tester.pumpAndSettle();
  await tester.tap(tag);
  await tester.pumpAndSettle();
}
