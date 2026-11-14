-- MK11 Arena — проверки перед и после миграции безопасности.
-- Скрипт ТОЛЬКО ЧИТАЕТ каталог и данные: ничего не создаёт, не меняет и не удаляет.
-- Выполняйте целиком в Supabase → SQL Editor от роли postgres.

-- ═══════════════════════════════════════════════════════════════════════════
-- ЧАСТЬ A. ДО МИГРАЦИИ
-- ═══════════════════════════════════════════════════════════════════════════

-- A1. Версия PostgreSQL и текущая роль. Роль должна быть postgres,
--     версия — 12 и выше (в Supabase это 15/17).
select
  current_setting('server_version') as pg_version,
  current_setting('server_version_num')::integer as pg_version_num,
  current_user as current_role;

-- A2. pgcrypto. Ожидается одна строка с schema = extensions и proname = hmac.
--     Если строк нет — включите pgcrypto в Database → Extensions.
select n.nspname as crypto_schema, p.proname as function_name
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.proname in ('hmac', 'gen_random_bytes')
order by 1, 2;

-- A3. Владелец таблиц. Все четыре таблицы должны принадлежать текущей роли
--     (postgres), иначе представления не обойдут RLS и сайт увидит пустой список.
select tablename, tableowner
from pg_tables
where schemaname = 'public'
  and tablename in ('participants', 'tournaments', 'settings', 'admin_users')
order by tablename;

-- A4. Колонки tournaments. До миграции не должно быть is_published и public_*.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'tournaments'
order by ordinal_position;

-- A5. Какие объекты уже есть в public. Ожидается: только таблицы,
--     представлений public_tournaments/public_settings ещё нет.
select table_name, table_type
from information_schema.tables
where table_schema = 'public'
order by table_type, table_name;

-- A6. Какие функции есть в public. До миграции: is_admin, participant_count.
select p.proname, pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by 1;

-- A7. Действующие RLS-политики. До миграции у tournaments и settings должны быть
--     публичные SELECT-политики с ролями {anon,authenticated}.
select tablename, policyname, cmd, roles,
       qual is not null as has_using,
       with_check is not null as has_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- A8. Права anon и authenticated. До миграции anon читает tournaments/settings
--     и не читает participants.
select
  has_table_privilege('anon', 'public.tournaments', 'SELECT') as anon_tournaments_select,
  has_table_privilege('anon', 'public.settings', 'SELECT') as anon_settings_select,
  has_table_privilege('anon', 'public.participants', 'SELECT') as anon_participants_select,
  has_table_privilege('anon', 'public.tournaments', 'INSERT') as anon_tournaments_insert,
  has_table_privilege('anon', 'public.tournaments', 'UPDATE') as anon_tournaments_update,
  has_table_privilege('anon', 'public.tournaments', 'DELETE') as anon_tournaments_delete,
  has_table_privilege('authenticated', 'public.tournaments', 'INSERT') as auth_tournaments_insert;

-- A8b. Права на последовательности до миграции. Прежняя схема выдавала
--      usage+select на ВСЕ последовательности схемы public (ожидается t).
select
  has_sequence_privilege('anon', pg_get_serial_sequence('public.participants', 'id'), 'USAGE') as anon_participants_usage,
  has_sequence_privilege('anon', pg_get_serial_sequence('public.participants', 'id'), 'SELECT') as anon_participants_select,
  has_sequence_privilege('anon', pg_get_serial_sequence('public.tournaments', 'id'), 'USAGE') as anon_tournaments_usage,
  has_sequence_privilege('authenticated', pg_get_serial_sequence('public.tournaments', 'id'), 'USAGE') as auth_tournaments_usage;

-- A9. Публикация Realtime. Турниров и settings здесь быть не должно.
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by tablename;

-- A10. Сколько турниров содержат ФИО во вложенном JSON (ожидается > 0 до миграции).
select
  count(*) as tournaments_total,
  count(*) filter (where players::text like '%fullName%') as players_with_fullname,
  count(*) filter (where rounds::text like '%fullName%') as rounds_with_fullname,
  count(*) filter (where champion::text like '%fullName%') as champion_with_fullname
from public.tournaments;

-- ═══════════════════════════════════════════════════════════════════════════
-- ЧАСТЬ B. ПОСЛЕ МИГРАЦИИ
-- ═══════════════════════════════════════════════════════════════════════════

-- B1. Базовая таблица закрыта, представления открыты.
--     Ожидается: t/f/t -> true, остальные false.
select
  has_table_privilege('anon', 'public.tournaments', 'SELECT') as anon_tournaments_select,
  has_table_privilege('anon', 'public.settings', 'SELECT') as anon_settings_select,
  has_table_privilege('anon', 'public.participants', 'SELECT') as anon_participants_select,
  has_table_privilege('anon', 'public.public_tournaments', 'SELECT') as anon_public_view,
  has_table_privilege('anon', 'public.public_settings', 'SELECT') as anon_public_settings,
  has_table_privilege('anon', 'public.tournaments', 'INSERT') as anon_insert,
  has_table_privilege('anon', 'public.tournaments', 'UPDATE') as anon_update,
  has_table_privilege('anon', 'public.tournaments', 'DELETE') as anon_delete;

-- B2. Служебные функции не вызываются анонимом.
--     Ожидается false у public_tournament_json и public_token.
select
  has_function_privilege('anon', 'public.public_tournament_json(jsonb)', 'EXECUTE') as anon_can_sanitize,
  has_function_privilege('anon', 'public.public_token(text)', 'EXECUTE') as anon_can_token,
  has_function_privilege('anon', 'public.public_id_key()', 'EXECUTE') as anon_can_key,
  has_function_privilege('anon', 'public.registration_open()', 'EXECUTE') as anon_can_registration_open;

-- B3. Единственные функции, доступные anon.
--     Ожидается participant_count и registration_open.
select p.proname, pg_get_function_identity_arguments(p.oid) as args
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and has_function_privilege('anon', p.oid, 'EXECUTE')
order by 1;

-- B4. Политики. anon должен встречаться только в participants INSERT.
select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- B5. Очищенные копии не содержат ФИО. Ожидается 0 во всех трёх колонках.
select
  count(*) as tournaments_total,
  count(*) filter (where public_players::text ~* 'fullName|full_name|contact') as players_leak,
  count(*) filter (where public_rounds::text ~* 'fullName|full_name|contact') as rounds_leak,
  count(*) filter (where public_champion::text ~* 'fullName|full_name|contact') as champion_leak
from public.tournaments;

-- B6. Публичное представление отдаёт данные и не содержит ФИО.
--     Ожидается: rows > 0 и leak = 0.
select
  count(*) as rows_visible,
  count(*) filter (where (players::text || rounds::text || coalesce(champion::text, '')) ~* 'fullName|full_name|contact')
    as rows_with_pii
from public.public_tournaments;

-- B7. Внутренние ID заменились на 16-hex псевдонимы, а равенство сохранено.
select
  count(*) filter (
    where (players -> 0 ->> 'id') ~ '^[0-9a-f]{16}$'
  ) as players_with_pseudonym,
  count(*) filter (
    where rounds -> 0 -> 'matches' -> 0 ->> 'winnerId' is not null
      and rounds -> 0 -> 'matches' -> 0 -> 'p1' ->> 'id'
        = rounds -> 0 -> 'matches' -> 0 ->> 'winnerId'
  ) as winner_matches_p1
from public.public_tournaments;

-- B8. Турниры и settings не публикуются в Realtime.
select tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by tablename;

-- B9. Последовательности после миграции.
--     Ожидается: anon_participants_usage = true, anon_participants_select = false,
--     anon_tournaments_usage = false, auth_tournaments_usage = true,
--     auth_participants_usage = true.
select
  has_sequence_privilege('anon', pg_get_serial_sequence('public.participants', 'id'), 'USAGE') as anon_participants_usage,
  has_sequence_privilege('anon', pg_get_serial_sequence('public.participants', 'id'), 'SELECT') as anon_participants_select,
  has_sequence_privilege('anon', pg_get_serial_sequence('public.tournaments', 'id'), 'USAGE') as anon_tournaments_usage,
  has_sequence_privilege('authenticated', pg_get_serial_sequence('public.tournaments', 'id'), 'USAGE') as auth_tournaments_usage,
  has_sequence_privilege('authenticated', pg_get_serial_sequence('public.participants', 'id'), 'USAGE') as auth_participants_usage;

-- B10. Контроль политик: ничего, кроме ожидаемого набора.
--      Ожидается 0 строк. Любая строка — забытая permissive-политика.
with expected(tablename, policyname) as (
  values
    ('participants', 'participants_public_insert'),
    ('participants', 'participants_admin_select'),
    ('participants', 'participants_admin_update'),
    ('participants', 'participants_admin_delete'),
    ('tournaments', 'tournaments_admin_select'),
    ('tournaments', 'tournaments_admin_insert'),
    ('tournaments', 'tournaments_admin_update'),
    ('tournaments', 'tournaments_admin_delete'),
    ('settings', 'settings_admin_select'),
    ('settings', 'settings_admin_update')
)
select p.tablename, p.policyname, p.cmd, p.roles
from pg_policies p
where p.schemaname = 'public'
  and p.tablename in ('participants', 'tournaments', 'settings')
  and not exists (
    select 1 from expected e
    where e.tablename = p.tablename
      and e.policyname = p.policyname
  )
order by p.tablename, p.policyname;
