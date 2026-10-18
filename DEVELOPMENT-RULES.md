# Parches - Development Rules (English Code Standard)

## 1. Language Policy
- **CODE: English 100%** - variables, functions, classes, files, commits, comments
- **UI: Spanish** - user-facing strings
- **CHAT: Spanish** - communication with PM/user
- DB columns: Keep Spanish for backward compat (nombre, quien_pago), new columns in English

## 2. Architecture
```
lib/
  app/view/app.dart
  core/env.dart, constants.dart, utils/
  features/
    patches/
      data/patches_repository.dart
      view/home_patches_page.dart, patch_detail_page.dart
    expenses/
      logic/balance_calculator.dart
      view/add_expense_sheet.dart
    members/...
  main_development.dart
  main_production.dart
```

## 3. Naming Conventions
- Files: snake_case.dart
- Classes: PascalCase
- Methods/vars: camelCase
- Repository: getPatches(), createPatch(), deletePatch(), watchPatches()
- Legacy aliases: crearParche() => createPatch() for backward compat

## 4. Security Checklist (Must Pass Before Merge)
- [ ] No secrets hardcoded
- [ ] RLS enabled on all tables (parches, miembros, gastos)
- [ ] `notify pgrst, 'reload schema';` after migrations
- [ ] Input validation: trim(), amount > 0, member exists
- [ ] try/catch on all Supabase inserts with fallback
- [ ] No created_by column unless it exists in DB

## 5. Git Workflow
- main: stable production (MVP1)
- develop: integration
- feature/*: new features
- backup/*: before breaking changes
- Commit: `feat(patches): add unequal split` `fix(repo): resolve PGRST204`

## 6. Code Quality Gates
- [ ] flutter analyze = 0 issues
- [ ] No *_1.dart duplicate files
- [ ] Repository has English + Spanish aliases
- [ ] BalanceCalculator supports both 'igual' and 'equal'
- [ ] Manual test passes: create patch -> 2 members -> expense 100k -> split 80/20 -> correct debt

## 7. Current Tech Debt to Track
- Table names in Spanish (parches, miembros, gastos) - keep for now, migrate in V2
- Old views in features/parches/view/ - kept as wrappers that export English versions
- Need to migrate to Riverpod for state management in V2

## 8. Roadmap
- MVP1 DONE: equal split
- Phase 3 TODO: unequal by amounts (Will $80k / Karoll $20k) - IN PROGRESS
- Phase 4 TODO: percentages and shares
- Phase 5 TODO: receipts, history, export

## 9. Supabase Tables
- parches: id, nombre, tipo, created_at
- miembros: id, parche_id, nombre, created_at
- gastos: id, parche_id, descripcion, monto_original, moneda, monto_cop, quien_pago, categoria, division_tipo, division_data, created_at

## 10. How to Restore (If Broken)
```powershell
git checkout main
git branch backup/mvp1-stable
Get-ChildItem -Recurse -Filter "*_1.dart" | Remove-Item -Force
flutter clean && flutter pub get
```
