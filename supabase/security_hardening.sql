-- MK11 Arena — защита персональных данных в публичном API.
-- Применяйте в Supabase → SQL Editor ПОСЛЕ supabase/schema.sql.
-- Запускать от имени владельца таблиц (в Supabase это роль postgres).
--
-- Скрипт не удаляет таблицы и строки, не меняет исходные JSON-снимки и ID.
-- Добавляются только служебная колонка публикации и очищенные копии JSON.
-- Повторный запуск безопасен. Откат: supabase/security_hardening_rollback.sql.

begin;

-- ── 0. Предусловия и совместимость ──────────────────────────────────────────
-- Проверяем версию PostgreSQL и владельца таблиц. Если запустить скрипт не от
-- владельца, представление начнёт работать с правами вызывающего: сработает
-- RLS и публичный сайт увидит пустой список. Лучше остановиться сразу.

do $pre$
declare
  v_owner text;
  v_bypass boolean;
begin
  if current_setting('server_version_num')::integer < 120000 then
    raise exception 'Нужен PostgreSQL 12 или новее, сейчас: %',
      current_setting('server_version');
  end if;

  select c.relowner::regrole::text
    into v_owner
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'tournaments';

  if v_owner is null then
    raise exception 'Таблица public.tournaments не найдена. Сначала примените supabase/schema.sql.';
  end if;

  select r.rolbypassrls or r.rolsuper
    into v_bypass
  from pg_roles r
  where r.rolname = current_user;

  if v_owner <> current_user and coalesce(v_bypass, false) is not true then
    raise exception
      'Скрипт запущен ролью %, а таблицы принадлежат %. Запустите его от владельца таблиц, иначе представления не обойдут RLS.',
      current_user, v_owner;
  end if;
end
$pre$;

-- pgcrypto нужен для HMAC-SHA256 и генерации секрета. В Supabase расширение
-- обычно уже установлено в схеме extensions.
do $crypto$
begin
  if to_regprocedure('extensions.hmac(bytea,bytea,text)') is null then
    begin
      create extension if not exists pgcrypto with schema extensions;
    exception
      when others then
        raise exception 'Не удалось включить pgcrypto: %. Включите расширение pgcrypto (Database → Extensions) и повторите.', sqlerrm;
    end;
  end if;

  if to_regprocedure('extensions.hmac(bytea,bytea,text)') is null then
    raise exception 'Функция extensions.hmac недоступна. Установите pgcrypto в схему extensions.';
  end if;
end
$crypto$;

-- ── 1. Секрет для публичных идентификаторов ─────────────────────────────────
-- ID участников — последовательные числа. md5('prefix' || id) их не скрывает:
-- перебор 1..N занимает миллисекунды. Публичный ID — усечённый HMAC-SHA256 от
-- ID с секретным ключом из закрытой таблицы. Ключ создаётся один раз, поэтому
-- псевдонимы стабильны между запусками скрипта и между турнирами.

create table if not exists public.app_secrets (
  name text primary key,
  value text not null,
  created_at timestamptz not null default now()
);

alter table public.app_secrets enable row level security;
revoke all on table public.app_secrets from public, anon, authenticated;

insert into public.app_secrets (name, value)
values ('public_id_key', encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (name) do nothing;

-- Читается только функциями и триггером ниже (они работают с правами владельца).
create or replace function public.public_id_key()
returns text
language sql
stable
security definer
set search_path = pg_catalog
as $fn$
  select s.value
  from public.app_secrets s
  where s.name = 'public_id_key';
$fn$;

-- Стабильный непрозрачный псевдоним: 16 hex-символов (64 бита) HMAC-SHA256.
-- 64 бита достаточно для 64 участников (вероятность коллизии ~10^-14), а
-- одинаковый вход всегда даёт одинаковый выход — сетка продолжает работать.
create or replace function public.public_token(p_value text)
returns text
language sql
stable
set search_path = pg_catalog
as $fn$
  select left(
    encode(
      extensions.hmac(
        convert_to(p_value, 'utf8'),
        convert_to(public.public_id_key(), 'utf8'),
        'sha256'
      ),
      'hex'
    ),
    16
  );
$fn$;

revoke all on function public.public_id_key() from public, anon, authenticated;
revoke all on function public.public_token(text) from public, anon, authenticated;

-- ── 2. Очистка JSON турнира ────────────────────────────────────────────────
-- Рекурсивно удаляет персональные ключи и заменяет внутренние числовые ID
-- (id, winnerId) на публичные псевдонимы. Ники, персонажи, счёт и структура
-- сетки сохраняются полностью.

create or replace function public.public_tournament_json(input jsonb)
returns jsonb
language plpgsql
stable
set search_path = pg_catalog
as $fn$
declare
  result jsonb;
begin
  if input is null then
    return null;
  end if;

  case jsonb_typeof(input)
    when 'object' then
      select coalesce(
        jsonb_object_agg(
          key,
          case
            when key in ('id', 'winnerId')
              and jsonb_typeof(value) in ('number', 'string')
              and (value #>> '{}') ~ '^[0-9]+$'
              then to_jsonb(public.public_token(value #>> '{}'))
            else public.public_tournament_json(value)
          end
        ),
        '{}'::jsonb
      )
      into result
      from jsonb_each(input)
      where key not in (
        'fullName',
        'full_name',
        'fullname',
        'contact',
        'contacts',
        'contactInfo',
        'email',
        'phone',
        'phoneNumber',
        'phone_number',
        'telegram',
        'whatsapp',
        'discord',
        'vk',
        'birthDate',
        'birth_date',
        'birthYear',
        'birth_year',
        'birthday',
        'address',
        'iin',
        'passport'
      );

      return result;

    when 'array' then
      select coalesce(jsonb_agg(public.public_tournament_json(value)), '[]'::jsonb)
      into result
      from jsonb_array_elements(input);

      return result;

    else
      return input;
  end case;
end;
$fn$;

-- Прямой вызов через /rest/v1/rpc/ закрыт: у anon и authenticated нет EXECUTE.
-- Представление эту функцию не вызывает, поэтому прав ей не требует.
revoke all on function public.public_tournament_json(jsonb) from public, anon, authenticated;

-- ── 3. Проверка «регистрация открыта» ───────────────────────────────────────
-- Политика INSERT на participants проверяет флаг регистрации. Читать settings
-- анониму больше нельзя, поэтому проверку выносим в SECURITY DEFINER функцию:
-- без неё регистрация падала бы с 42501 сразу после отзыва SELECT на settings.

create or replace function public.registration_open()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $fn$
  select coalesce(
    (select s.registration_closed from public.settings s where s.id = 1),
    false
  ) = false;
$fn$;

revoke all on function public.registration_open() from public;
grant execute on function public.registration_open() to anon, authenticated;

-- ── 4. Флаг публикации ─────────────────────────────────────────────────────
-- Существующие строки получают true, поэтому публичная выдача не меняется.
-- Турнир можно скрыть, не удаляя: update public.tournaments
-- set is_published = false where id = ...;

alter table public.tournaments
  add column if not exists is_published boolean not null default true;

-- ── 5. Очищенные копии JSON ────────────────────────────────────────────────
-- Представление не может вызывать служебные функции: PostgreSQL проверяет
-- EXECUTE от имени вызывающего (anon), а выдать его нельзя — иначе anon
-- получил бы оракул «ID → псевдоним» и восстановил исходные номера перебором.
-- Поэтому проекция считается заранее и хранится рядом с исходным JSON.

alter table public.tournaments
  add column if not exists public_players jsonb,
  add column if not exists public_rounds jsonb,
  add column if not exists public_third_place jsonb,
  add column if not exists public_champion jsonb;

-- Первичное заполнение: меняются только новые колонки, исходные не трогаются.
update public.tournaments t
set public_players = public.public_tournament_json(t.players),
    public_rounds = public.public_tournament_json(t.rounds),
    public_third_place = public.public_tournament_json(t.third_place),
    public_champion = public.public_tournament_json(t.champion)
where t.public_players is null
   or t.public_rounds is null
   or (t.third_place is not null and t.public_third_place is null)
   or (t.champion is not null and t.public_champion is null);

-- Пересчёт при каждой записи: администратор не сможет случайно (или намеренно)
-- записать в публичные колонки неочищенные данные.
create or replace function public.sync_public_tournament_json()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $fn$
begin
  new.public_players := public.public_tournament_json(new.players);
  new.public_rounds := public.public_tournament_json(new.rounds);
  new.public_third_place := public.public_tournament_json(new.third_place);
  new.public_champion := public.public_tournament_json(new.champion);
  return new;
end;
$fn$;

revoke all on function public.sync_public_tournament_json() from public, anon, authenticated;

drop trigger if exists sync_public_tournament_json on public.tournaments;
create trigger sync_public_tournament_json
  before insert or update on public.tournaments
  for each row
  execute function public.sync_public_tournament_json();

-- ── 6. Публичные представления ──────────────────────────────────────────────
-- Представления принадлежат владельцу таблиц и выполняются с его правами,
-- поэтому обходят RLS. Наружу отдаются только перечисленные колонки, а JSON
-- уже очищен. security_barrier не даёт протащить условия пользователя внутрь
-- представления раньше фильтра.

drop view if exists public.public_tournaments;
create view public.public_tournaments
with (security_barrier = true)
as
select
  t.id,
  t.title,
  t.description,
  t.date,
  t.registration_end,
  t.player_limit,
  t.platform,
  t.bo,
  t.final_bo,
  t.format,
  t.status,
  t.public_players as players,
  t.public_rounds as rounds,
  t.public_third_place as third_place,
  t.public_champion as champion
from public.tournaments t
-- is_published=true по умолчанию: поведение сайта не меняется.
-- Статус draft намеренно НЕ скрывается: в этом проекте это «Набор участников»
-- с открытой регистрацией, он показывается на /tournaments и на главной.
where t.is_published;

drop view if exists public.public_settings;
create view public.public_settings
with (security_barrier = true)
as
select registration_closed
from public.settings
where id = 1;

revoke all on public.public_tournaments from public, anon, authenticated;
revoke all on public.public_settings from public, anon, authenticated;

grant select on public.public_tournaments to anon, authenticated;
grant select on public.public_settings to anon, authenticated;

-- ── 7. Права на базовые таблицы ─────────────────────────────────────────────

alter table public.participants enable row level security;
alter table public.tournaments enable row level security;
alter table public.settings enable row level security;

revoke all on table public.participants from public, anon, authenticated;
grant insert (nickname, full_name, main_character, contact)
  on public.participants to anon, authenticated;
grant select, update, delete on table public.participants to authenticated;

revoke all on table public.tournaments from public, anon, authenticated;
grant select, insert, update, delete on table public.tournaments to authenticated;

revoke all on table public.settings from public, anon, authenticated;
grant select, update on table public.settings to authenticated;

grant usage on schema public to anon, authenticated;

-- Последовательности: только то, что реально нужно.
-- USAGE на participants.id требуется анонимной заявке (nextval при INSERT).
-- USAGE на tournaments.id нужен администратору при создании турнира.
-- SELECT на последовательности приложению не нужен, широкие гранты убираем.
do $sequences$
declare
  v_participants_seq text := pg_get_serial_sequence('public.participants', 'id');
  v_tournaments_seq text := pg_get_serial_sequence('public.tournaments', 'id');
begin
  if v_participants_seq is null or v_tournaments_seq is null then
    raise exception 'Не найдены identity-последовательности public.participants/public.tournaments.';
  end if;

  revoke select on all sequences in schema public from public, anon, authenticated;
  revoke usage on all sequences in schema public from anon, authenticated;

  execute format('grant usage on sequence %s to anon, authenticated', v_participants_seq);
  execute format('grant usage on sequence %s to authenticated', v_tournaments_seq);
end
$sequences$;

-- ── 8. RLS-политики ─────────────────────────────────────────────────────────
-- Сначала удаляем ВСЕ прежние политики на трёх таблицах. Прежняя схема выдавала
-- `using (true)` для anon и authenticated; такие политики нельзя оставлять,
-- даже если они называются иначе. Затем создаём только необходимый набор.
-- RLS на таблицах остаётся включённым, поэтому внутри транзакции доступа нет.

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
    raise notice 'Удалена прежняя политика %.%', r.tablename, r.policyname;
  end loop;
end
$policies$;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $fn$
  select exists (
    select 1 from public.admin_users where user_id = auth.uid()
  );
$fn$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

-- Заявка: аноним и пользователь могут только добавить запись, пока лобби
-- открыто. Проверка идёт через SECURITY DEFINER функцию, потому что прямой
-- SELECT на settings у anon отозван.
drop policy if exists participants_public_insert on public.participants;
create policy participants_public_insert
  on public.participants for insert
  to anon, authenticated
  with check (
    status = 'accepted'
    and public.registration_open()
  );

drop policy if exists participants_admin_select on public.participants;
create policy participants_admin_select
  on public.participants for select
  to authenticated
  using (public.is_admin());

drop policy if exists participants_admin_update on public.participants;
create policy participants_admin_update
  on public.participants for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists participants_admin_delete on public.participants;
create policy participants_admin_delete
  on public.participants for delete
  to authenticated
  using (public.is_admin());

-- Турниры: публичного SELECT больше нет, всё чтение — через представление.
drop policy if exists tournaments_public_select on public.tournaments;
drop policy if exists tournaments_admin_select on public.tournaments;
create policy tournaments_admin_select
  on public.tournaments for select
  to authenticated
  using (public.is_admin());

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

-- Настройки: SELECT и UPDATE только администратору, INSERT/DELETE не выдаются.
drop policy if exists settings_public_select on public.settings;
drop policy if exists settings_admin_select on public.settings;
create policy settings_admin_select
  on public.settings for select
  to authenticated
  using (public.is_admin());

drop policy if exists settings_admin_update on public.settings;
create policy settings_admin_update
  on public.settings for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ── 9. Realtime ─────────────────────────────────────────────────────────────
-- Realtime отдаёт подписчику целую строку, обходя колонки представления.
-- Турниры и настройки в публикации быть не должны: в JSON турнира лежат ФИО.
-- Участники остаются — их изменения получает только администратор (RLS).

do $realtime$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'tournaments'
    ) then
      alter publication supabase_realtime drop table public.tournaments;
    end if;

    if exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'settings'
    ) then
      alter publication supabase_realtime drop table public.settings;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'participants'
    ) then
      alter publication supabase_realtime add table public.participants;
    end if;
  end if;
end
$realtime$;

-- ── 10. Перезагрузка схемы PostgREST ────────────────────────────────────────
notify pgrst, 'reload schema';

commit;

-- ── Проверка после применения (выполните отдельно в SQL Editor) ─────────────
-- 1) anon не читает базовые таблицы, но читает представления:
--    select has_table_privilege('anon', 'public.tournaments', 'SELECT');       -- false
--    select has_table_privilege('anon', 'public.settings', 'SELECT');          -- false
--    select has_table_privilege('anon', 'public.participants', 'SELECT');      -- false
--    select has_table_privilege('anon', 'public.public_tournaments', 'SELECT');-- true
-- 2) anon ничего не может менять:
--    select has_table_privilege('anon', 'public.tournaments', 'INSERT');       -- false
--    select has_table_privilege('anon', 'public.tournaments', 'UPDATE');       -- false
--    select has_table_privilege('anon', 'public.tournaments', 'DELETE');       -- false
--    select has_table_privilege('anon', 'public.settings', 'UPDATE');          -- false
-- 3) служебные функции не вызываются напрямую:
--    select has_function_privilege('anon', 'public.public_tournament_json(jsonb)', 'EXECUTE'); -- false
--    select has_function_privilege('anon', 'public.public_token(text)', 'EXECUTE');            -- false
-- 4) полный список политик (в ролях не должно быть anon, кроме participants INSERT):
--    select tablename, policyname, cmd, roles from pg_policies
--    where schemaname = 'public' order by tablename, policyname;
-- 5) другие функции, доступные anon (ожидаются только participant_count и
--    registration_open):
--    select p.proname, pg_get_function_identity_arguments(p.oid) as args
--    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and has_function_privilege('anon', p.oid, 'EXECUTE');
-- 6) турниры и settings не входят в публикацию Realtime:
--    select tablename from pg_publication_tables where pubname = 'supabase_realtime';
-- 7) очищенная копия не содержит ФИО:
--    select public_players from public.tournaments;
