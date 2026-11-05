# kadi

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Vérifier

Les six parcours d'`EXPERIENCE.md` (Key Flows), en clair et en sombre, avec
l'aller-retour de sauvegarde et le plancher d'accessibilité, sur l'app montée
entière :

```
flutter test test/e2e
```

La même suite sur le téléphone branché, sur l'app debug (`.debug`, base en
mémoire : la release installée et ses données ne sont pas touchées) :

```
flutter test integration_test -d <téléphone>
```

## Licences

Les pictos des articles viennent de [Phosphor Icons](https://phosphoricons.com/)
2.1.1 (style regular) : police `assets/fonts/Phosphor-Regular.ttf`, reprise de
`@phosphor-icons/web` 2.1.1. Licence MIT, Copyright (c) 2020-2021 Phosphor
Icons ; texte complet dans `assets/fonts/LICENSE`.
