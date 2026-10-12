-- Osada: lista graczy i podgląd wiosek.
-- Wklej całość w Supabase → SQL Editor → Run (jednorazowo).
-- Tabela jest zamknięta dla świata; gra korzysta wyłącznie z 3 funkcji poniżej.

create table if not exists public.osada_villages (
  id uuid primary key,
  token text not null,
  name text not null,
  title text,
  lvl int default 1,
  hall int default 1,
  power int default 0,
  raids int default 0,
  loots int default 0,
  snapshot jsonb,
  updated_at timestamptz default now()
);
alter table public.osada_villages enable row level security;
revoke all on public.osada_villages from anon, authenticated;

-- zapis własnej wioski (nadpisać można tylko swój wiersz — wymaga tajnego tokenu z urządzenia gracza)
create or replace function public.osada_save(
  p_id uuid, p_token text, p_name text, p_title text, p_lvl int, p_hall int,
  p_power int, p_raids int, p_loots int, p_snap jsonb)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if p_token is null or length(p_token) < 20 or length(p_name) > 24 or pg_column_size(p_snap) > 60000 then
    return false;
  end if;
  insert into osada_villages(id, token, name, title, lvl, hall, power, raids, loots, snapshot, updated_at)
  values (p_id, p_token, p_name, p_title, p_lvl, p_hall, p_power, p_raids, p_loots, p_snap, now())
  on conflict (id) do update set
    name = excluded.name, title = excluded.title, lvl = excluded.lvl, hall = excluded.hall,
    power = excluded.power, raids = excluded.raids, loots = excluded.loots,
    snapshot = excluded.snapshot, updated_at = now()
  where osada_villages.token = p_token;
  return found;
end $$;

-- lista osad (bez tokenów)
create or replace function public.osada_list()
returns table(id uuid, name text, title text, lvl int, hall int, power int, raids int, loots int, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select id, name, title, lvl, hall, power, raids, loots, updated_at
  from osada_villages order by updated_at desc limit 100
$$;

-- podgląd jednej osady
create or replace function public.osada_get(p_id uuid)
returns table(id uuid, name text, title text, lvl int, hall int, snapshot jsonb, updated_at timestamptz)
language sql security definer set search_path = public as $$
  select id, name, title, lvl, hall, snapshot, updated_at from osada_villages where id = p_id
$$;

revoke all on function public.osada_save(uuid,text,text,text,int,int,int,int,int,jsonb) from public;
revoke all on function public.osada_list() from public;
revoke all on function public.osada_get(uuid) from public;
grant execute on function public.osada_save(uuid,text,text,text,int,int,int,int,int,jsonb) to anon, authenticated;
grant execute on function public.osada_list() to anon, authenticated;
grant execute on function public.osada_get(uuid) to anon, authenticated;
