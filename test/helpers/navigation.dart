import 'package:flutter_test/flutter_test.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:material_ui/material_ui.dart';

/// Onglet Paramètres de la Barre de navigation.
final parametresTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(StringsFr.parametres),
);

/// Onglet Recettes de la Barre de navigation.
final recettesTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(StringsFr.tabRecettes),
);

/// Onglet Liste de la Barre de navigation.
final listeTab = find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(StringsFr.tabListe),
);
