import 'package:uuid/uuid.dart';

/// Espace de noms Kadi des ids de fréquent. Figé : le changer changerait
/// l'id de tous les fréquents et casserait la fusion à l'import (AD-9).
const kadiFrequentNamespace = '082c8fba-0bf2-4d09-9021-d42623d4c4f3';

/// Seul calcul de l'id d'un fréquent (AD-17) : UUID v5 de l'id de son
/// article, dans [kadiFrequentNamespace]. Un fréquent par article.
String frequentId(String articleId) =>
    const Uuid().v5(kadiFrequentNamespace, articleId);
