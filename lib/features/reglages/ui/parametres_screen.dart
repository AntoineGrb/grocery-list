import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kadi/app/actions/exporter_mes_donnees.dart';
import 'package:kadi/app/actions/importer_une_sauvegarde.dart';
import 'package:kadi/core/backup/backup_import.dart';
import 'package:kadi/core/router/app_router.dart';
import 'package:kadi/core/settings/settings_providers.dart';
import 'package:kadi/core/settings/settings_repository.dart';
import 'package:kadi/core/strings/strings_fr.dart';
import 'package:kadi/core/ui/error_snackbar.dart';
import 'package:material_ui/material_ui.dart';

/// Paramètres : écran poussé plein écran, flèche retour, sans Barre de
/// navigation. Lignes de paramètre (`settings-row`) en Switch M3 :
/// Écran allumé (R14) et groupement de la Liste par rayon ; dessous, la
/// lignes de navigation « Parcours » (Paramètres › Parcours, R19),
/// « Articles » (Paramètres › Articles, R18) et « Fréquents » (Paramètres ›
/// Fréquents, R16), puis les
/// lignes « Exporter mes données » et « Importer une sauvegarde » (R21).
///
/// Les switches suivent les réglages en base (AD-1) et y écrivent par le
/// `SettingsRepository` (AD-2) : une écriture qui échoue laisse le switch à
/// la valeur en base et montre un snackbar.
class ParametresScreen extends ConsumerWidget {
  const ParametresScreen({super.key});

  Future<void> _write(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(SettingsRepository repository) write,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await write(ref.read(settingsRepositoryProvider));
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.reglageImpossible);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text(StringsFr.parametres)),
      body: settings == null
          ? const SizedBox.shrink()
          : ListView(
              children: [
                _SettingsSwitch(
                  title: StringsFr.garderEcranAllume,
                  subtitle: StringsFr.garderEcranAllumeDetail,
                  value: settings.keepScreenOn,
                  onChanged: (value) =>
                      _write(context, ref, (r) => r.setKeepScreenOn(value)),
                ),
                _SettingsSwitch(
                  title: StringsFr.grouperParRayon,
                  subtitle: StringsFr.grouperParRayonDetail,
                  value: settings.groupByRayon,
                  onChanged: (value) =>
                      _write(context, ref, (r) => r.setGroupByRayon(value)),
                ),
                _NavigationRow(
                  title: StringsFr.parcours,
                  subtitle: StringsFr.parcoursDetail,
                  onTap: () => context.push(AppRoutes.parcours),
                ),
                _NavigationRow(
                  title: StringsFr.articlesTitre,
                  subtitle: StringsFr.articlesDetail,
                  onTap: () => context.push(AppRoutes.articles),
                ),
                _NavigationRow(
                  title: StringsFr.frequentsTitre,
                  subtitle: StringsFr.frequentsDetail,
                  onTap: () => context.push(AppRoutes.frequents),
                ),
                const _ExportRow(),
                const _ImportRow(),
              ],
            ),
    );
  }
}

/// Ligne de paramètre à Switch M3 : libellé en `body-large`, texte d'aide en
/// `body-medium` `on-surface-variant` ; les textes passent à la ligne en
/// grande police, jamais tronqués.
class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Ligne de paramètre de navigation : libellé, texte d'aide et chevron en
/// `on-surface-variant` ; pousse son sous-écran ([onTap]).
class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variant = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      onTap: onTap,
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(color: variant),
      ),
      trailing: Icon(Icons.chevron_right, color: variant),
    );
  }
}

/// Ligne « Exporter mes données » : écrit l'archive de sauvegarde et l'ouvre
/// dans la feuille de partage. Désactivée pendant l'export (pas de double
/// export) ; « Sauvegarde prête. » au retour du partage, rien s'il est
/// fermé sans choix, « Export impossible. » sur un échec.
class _ExportRow extends ConsumerStatefulWidget {
  const _ExportRow();

  @override
  ConsumerState<_ExportRow> createState() => _ExportRowState();
}

class _ExportRowState extends ConsumerState<_ExportRow> {
  var _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    final export = ref.read(exporterMesDonneesProvider);
    setState(() => _exporting = true);
    try {
      final result = await export();
      if (result == ExportResult.shared && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text(StringsFr.sauvegardePrete)),
        );
      }
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.exportImpossible);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      enabled: !_exporting,
      onTap: _exporting ? null : _export,
      title: Text(
        StringsFr.exporterMesDonnees,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        StringsFr.exporterMesDonneesDetail,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Ligne « Importer une sauvegarde » : ouvre le sélecteur de fichier et
/// fusionne la sauvegarde choisie avec les données, sans confirmation (C9).
/// Désactivée pendant l'import ; « Sauvegarde importée. » après un import,
/// « Ce fichier n’est pas une sauvegarde Kadi. » pour un fichier invalide,
/// « Import impossible. » sur un échec d'écriture, rien si le sélecteur est
/// fermé sans choix.
class _ImportRow extends ConsumerStatefulWidget {
  const _ImportRow();

  @override
  ConsumerState<_ImportRow> createState() => _ImportRowState();
}

class _ImportRowState extends ConsumerState<_ImportRow> {
  var _importing = false;

  Future<void> _import() async {
    if (_importing) return;
    final messenger = ScaffoldMessenger.of(context);
    final import = ref.read(importerUneSauvegardeProvider);
    setState(() => _importing = true);
    try {
      final result = await import();
      if (result == ImportResult.imported && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text(StringsFr.sauvegardeImportee)),
        );
      }
    } on InvalidBackupException {
      showErrorSnackBar(messenger, StringsFr.pasUneSauvegardeKadi);
    } catch (_) {
      showErrorSnackBar(messenger, StringsFr.importImpossible);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      enabled: !_importing,
      onTap: _importing ? null : _import,
      title: Text(
        StringsFr.importerUneSauvegarde,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        StringsFr.importerUneSauvegardeDetail,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
