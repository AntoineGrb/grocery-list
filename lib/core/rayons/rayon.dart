import '../strings/strings_fr.dart';

/// Les 13 rayons, figés dans le code (AD-11).
///
/// La base ne stocke que [code]. L'ordre de l'énumération ne sert qu'à l'ordre
/// du parcours par défaut : l'ordre d'affichage vient toujours de
/// `settings.route_order`.
enum Rayon {
  fruitsLegumes('fruits-legumes'),
  boulangerie('boulangerie'),
  viandePoisson('viande-poisson'),
  cremerie('cremerie'),
  epicerieSalee('epicerie-salee'),
  epicerieSucree('epicerie-sucree'),
  surgeles('surgeles'),
  platsPrepares('plats-prepares'),
  boissons('boissons'),
  hygiene('hygiene'),
  entretien('entretien'),
  bebeAnimaux('bebe-animaux'),
  divers('divers');

  const Rayon(this.code);

  /// Code stable stocké en base.
  final String code;

  static final Map<String, Rayon> _byCode = {
    for (final r in Rayon.values) r.code: r,
  };

  /// Le rayon de [code], ou `null` si le code est inconnu.
  static Rayon? tryFromCode(String code) => _byCode[code];

  /// Le rayon de [code] ; lève une [FormatException] si le code est inconnu.
  static Rayon fromCode(String code) =>
      tryFromCode(code) ?? (throw FormatException('Rayon inconnu : $code'));

  /// Nom affiché dans la pastille.
  String get label => switch (this) {
    Rayon.fruitsLegumes => StringsFr.rayonFruitsLegumes,
    Rayon.boulangerie => StringsFr.rayonBoulangerie,
    Rayon.viandePoisson => StringsFr.rayonViandePoisson,
    Rayon.cremerie => StringsFr.rayonCremerie,
    Rayon.epicerieSalee => StringsFr.rayonEpicerieSalee,
    Rayon.epicerieSucree => StringsFr.rayonEpicerieSucree,
    Rayon.surgeles => StringsFr.rayonSurgeles,
    Rayon.platsPrepares => StringsFr.rayonPlatsPrepares,
    Rayon.boissons => StringsFr.rayonBoissons,
    Rayon.hygiene => StringsFr.rayonHygiene,
    Rayon.entretien => StringsFr.rayonEntretien,
    Rayon.bebeAnimaux => StringsFr.rayonBebeAnimaux,
    Rayon.divers => StringsFr.rayonDivers,
  };

  /// Nom lu par TalkBack (« Fruits et légumes » plutôt que « Fruits & légumes »).
  String get spokenLabel => switch (this) {
    Rayon.fruitsLegumes => StringsFr.rayonFruitsLegumesLu,
    Rayon.viandePoisson => StringsFr.rayonViandePoissonLu,
    Rayon.bebeAnimaux => StringsFr.rayonBebeAnimauxLu,
    _ => label,
  };
}
