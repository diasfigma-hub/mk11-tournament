-- MK11 Arena — полный откат миграции безопасности.
--
-- ВНИМАНИЕ: после отката anon снова сможет читать public.tournaments напрямую,
-- то есть ФИО и контакты участников снова станут публичными.
-- Используйте только если нужно временно вернуть прежнее поведение.
--
-- Скрипт возвращает ровно то состояние, которое описано в supabase/schema.sql
-- ДО миграции: прежние GRANT, прежние RLS-политики, отсутствие представлений,
-- функций очистки и флага is_published. Таблицы, строки, ID и JSON не трогаются.
-- Повторный запуск безопасен.

begin;

-- ── 1. Представления и функции миграции ─────────────────────────────────────

drop view if exists public.public_tournaments;
drop view if exists public.public_settings;

-- Политика вставки заявки ссылается на registration_open(), поэтому удаляем её
-- до функций и пересоздаём ниже в исходном виде.
drop policy if exists participants_public_insert on public.participants;

-- Представления и политика уже удалены, зависимостей больше нет.
drop trigger if exists sync_public_tournament_json on public.tournaments;
drop function if exists public.sync_public_tournament_json();
drop function if exists public.public_tournament_json(jsonb);
drop function if exists public.public_token(text);
drop function if exists public.public_id_key();
drop function if exists public.registration_open();

-- ── 2. Служебные колонки ────────────────────────────────────────────────────
-- is_published и public_* добавлены миграцией; в прежней схеме их не было.
-- Исходные players/rounds/third_place/champion не затрагиваются.

alter table public.tournaments
  drop column if exists public_players,
  drop column if exists public_rounds,
  drop column if exists public_third_place,
  drop column if exists public_champion,
  drop column if exists is_published;

-- ── 3. Секрет публичных ID ──────────────────────────────────────────────────
-- Таблица создана миграцией и содержит только сгенерированный ключ.

drop table if exists public.app_secrets;

-- ── 4. Прежние GRANT ────────────────────────────────────────────────────────

alter table public.participants enable row level security;
alter table public.tournaments enable row level security;
alter table public.settings enable row level security;

revoke all on table public.participants from public, anon, authenticated;
grant insert (nickname, full_name, main_character, contact)
  on public.participants to anon, authenticated;
grant select, update, delete on table public.participants to authenticated;

revoke all on table public.tournaments from public, anon, authenticated;
grant select on table public.tournaments to anon;
grant select, insert, update, delete on table public.tournaments to authenticated;

revoke all on table public.settings from public, anon, authenticated;
grant select on table public.settings to anon;
grant select, update on table public.settings to authenticated;

grant usage on schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;

-- ── 5. Прежние RLS-политики ─────────────────────────────────────────────────
-- Удаляем все политики, созданные миграцией (и возможные остатки), затем
-- восстанавливаем исходный набор из прежней схемы.

do $policies$
declare
  r record;
begin
  for r in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('participants', 'tournaments', 'settings')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end
$policies$;

drop policy if exists participants_public_insert on public.participants;
create policy participants_public_insert
  on public.participants for insert
  to anon, authenticated
  with check (
    status = 'accepted'
    and coalesce(
      (select registration_closed from public.settings where id = 1),
      false
    ) = false
  );

drop policy if exists tournaments_admin_select on public.tournaments;
drop policy if exists tournaments_public_select on public.tournaments;
create policy tournaments_public_select
  on public.tournaments for select
  to anon, authenticated
  using (true);

drop policy if exists tournaments_admin_insert on public.tournaments;
create policy tournaments_admin_insert
  on public.tournaments for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists tournaments_admin_update on public.tournaments;
create policy tournaments_admin_update
  on public.tournaments for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists tournaments_admin_delete on public.tournaments;
create policy tournaments_admin_delete
  on public.tournaments for delete
  to authenticated
  using (public.is_admin());

drop policy if exists settings_admin_select on public.settings;
drop policy if exists settings_public_select on public.settings;
create policy settings_public_select
  on public.settings for select
  to anon, authenticated
  using (true);

drop policy if exists settings_admin_update on public.settings;
create policy settings_admin_update
  on public.settings for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

notify pgrst, 'reload schema';

commit;

-- После отката фронтенд тоже нужно вернуть на прямое чтение таблиц:
-- src/api/tournaments.js (getAll/getById вместо getPublicAll/getPublicById)
-- и src/api/settings.js (таблица settings вместо public_settings),
-- иначе публичные страницы будут обращаться к удалённым представлениям.
