# Parches - Divide gastos en parches
App Flutter + Supabase - MVP1 funcionando en Chrome.
Fix: Home ya no usa stream, usa Future + pull to refresh. Arregla el bug de "No hay parches" en localhost:65114.
## Correr
flutter pub get
flutter run -d chrome --target lib/main_development.dart --dart-define=SUPABASE_URL=TU_URL --dart-define=SUPABASE_ANON_KEY=TU_KEY
