import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';

import '../test/e2e/accessibilite_test.dart';
import '../test/e2e/e2e_harness.dart';
import '../test/e2e/flux_1_dimanche_soir_test.dart';
import '../test/e2e/flux_2_au_magasin_test.dart';
import '../test/e2e/flux_3_ajout_eclair_test.dart';
import '../test/e2e/flux_4_saisir_une_recette_test.dart';
import '../test/e2e/flux_5_recette_du_mercredi_test.dart';
import '../test/e2e/flux_6_premier_lancement_test.dart';
import '../test/e2e/sauvegarde_test.dart';

/// La suite de bout en bout de `test/e2e/`, jouée sur le téléphone :
///
///     flutter test integration_test -d <téléphone>
///
/// Elle tourne sur l'app debug (`applicationIdSuffix ".debug"`), sur une
/// base en mémoire : jamais sur les données de la release installée.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Sur le téléphone, le contenu fourni se lit dans le bundle de l'app, pas
  // sur le disque du dépôt.
  seedAssetsReader = () async => {
    for (final path in seedAssetPaths) path: await rootBundle.loadString(path),
  };

  flux1DimancheSoir();
  flux2AuMagasin();
  flux3AjoutEclair();
  flux4SaisirUneRecette();
  flux5RecetteDuMercredi();
  flux6PremierLancement();
  sauvegarde();
  accessibilite();
}
