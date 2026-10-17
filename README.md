# Parches 🍕 - Divide gastos en parches

App Flutter + Supabase para dividir gastos entre amigos. 
MVP1: Crear parche, añadir miembros, registrar gastos en COP/THB/VND/USD y ver quién debe a quién.

## Demo del bug que arreglamos
Antes se quedaba en "No hay parches" aunque había datos en Supabase (el flash que viste en localhost:65114). 
Ahora usa Future + pull-to-refresh en lugar de Stream de Realtime.

## Cómo correrlo

1. Instalar dependencias
\\\ash
flutter pub get
\\\

2. Correr en Chrome con tu Supabase
\\\ash
flutter run -d chrome --target lib/main_development.dart --dart-define=SUPABASE_URL=TU_URL --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
\\\

## Estructura
- lib/features/parches/view/home_parches_page.dart -> lista de parches (fix)
- lib/features/parches/data/parches_repository.dart -> getParches() future
- supabase/migrations/001_parches_mvp1.sql -> tablas

Hecho por @willdeviaje desde Mosquera.
