# PARCHES MVP1 - Proyecto desde cero

## 1. Instalar dependencias
flutter pub get

## 2. Correr en celular (con Supabase Cloud)
flutter run --target lib/main_development.dart --dart-define=SUPABASE_URL=https://TU_URL.supabase.co --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY

## 3. Si quieres crear las plataformas nativas (android/ios) porque no existen:
flutter create --platforms=android,ios .
Luego vuelve a correr flutter pub get y flutter run
