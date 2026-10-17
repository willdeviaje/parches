-- MVP1 PARCHES - IDEMPOTENTE
create table if not exists public.parches (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  tipo text not null default 'corto',
  created_at timestamptz default now()
);
create table if not exists public.miembros (
  id uuid primary key default gen_random_uuid(),
  parche_id uuid not null references public.parches(id) on delete cascade,
  nombre text not null,
  created_at timestamptz default now()
);
create table if not exists public.gastos (
  id uuid primary key default gen_random_uuid(),
  parche_id uuid not null references public.parches(id) on delete cascade,
  descripcion text not null,
  monto_original numeric not null,
  moneda text not null default 'COP',
  monto_cop integer not null,
  quien_pago text not null,
  categoria text default 'general',
  created_at timestamptz default now()
);
alter table public.parches enable row level security;
alter table public.miembros enable row level security;
alter table public.gastos enable row level security;
drop policy if exists "Allow all parches" on public.parches;
create policy "Allow all parches" on public.parches for all to anon, authenticated using (true) with check (true);
drop policy if exists "Allow all miembros" on public.miembros;
create policy "Allow all miembros" on public.miembros for all to anon, authenticated using (true) with check (true);
drop policy if exists "Allow all gastos" on public.gastos;
create policy "Allow all gastos" on public.gastos for all to anon, authenticated using (true) with check (true);
