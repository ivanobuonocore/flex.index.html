# packages/design-system

Token e temi (vedi `docs/product/05-design-system.md`): colori, tipografia, spaziature, raggi,
ombre, motion. Unica fonte di verità per lo stile visivo — nessuna feature dovrebbe definire i
propri valori (AGENTS.md, "Design System").

## Contenuto

- `src/colors.dart`, `src/typography.dart`, `src/spacing.dart`, `src/radii.dart`,
  `src/shadows.dart`, `src/motion.dart` — token individuali.
- `src/theme.dart` — `AppTheme.light()` / `AppTheme.dark()`, `ThemeData` pronti per `MaterialApp`.

## Nota

Il font Inter è referenziato come `fontFamily` ma i file `.ttf` non sono ancora inclusi
(vedi commento in `src/typography.dart`); vanno aggiunti come asset in `apps/mobile` prima del
rilascio pubblico. Non influisce sulla struttura del Design System.

## Test

```
cd packages/design-system && flutter test
```
