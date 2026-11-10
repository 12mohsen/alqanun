-- =====================================================================
--  دليل المسار القضائي — مخطط قاعدة البيانات
--  مشروع Supabase مستقل خاص بهذا التطبيق وحده.
--  شغّله مرة واحدة في: Supabase ← SQL Editor ← New query ← Run
--  آمن للتكرار: كل شيء فيه IF NOT EXISTS أو DROP ... IF EXISTS.
-- =====================================================================

-- ---------------------------------------------------------------- القضايا
create table if not exists public.cases (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null default auth.uid()
                          references auth.users(id) on delete cascade,
  payload     jsonb       not null default '{}'::jsonb,
  deleted_at  timestamptz,          -- شاهد الحذف: الصف يبقى معلَّمًا فلا يعود من جهاز آخر
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

-- للترقية إن كان الجدول موجودًا من قبل بلا هذا العمود
alter table public.cases add column if not exists deleted_at timestamptz;

create index if not exists cases_user_idx    on public.cases (user_id);
create index if not exists cases_updated_idx on public.cases (user_id, updated_at desc);

-- ------------------------------------------------- إعدادات الذكاء الاصطناعي
create table if not exists public.settings (
  user_id     uuid        primary key default auth.uid()
                          references auth.users(id) on delete cascade,
  ai          jsonb       not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- =====================================================================
--  أمن الصفوف — لا يقرأ أحد صفوف غيره ولو حمل المفتاح العام
-- =====================================================================
alter table public.cases    enable row level security;
alter table public.settings enable row level security;

drop policy if exists cases_select on public.cases;
drop policy if exists cases_insert on public.cases;
drop policy if exists cases_update on public.cases;
drop policy if exists cases_delete on public.cases;

create policy cases_select on public.cases
  for select using (auth.uid() = user_id);
create policy cases_insert on public.cases
  for insert with check (auth.uid() = user_id);
create policy cases_update on public.cases
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy cases_delete on public.cases
  for delete using (auth.uid() = user_id);

drop policy if exists settings_select on public.settings;
drop policy if exists settings_insert on public.settings;
drop policy if exists settings_update on public.settings;
drop policy if exists settings_delete on public.settings;

create policy settings_select on public.settings
  for select using (auth.uid() = user_id);
create policy settings_insert on public.settings
  for insert with check (auth.uid() = user_id);
create policy settings_update on public.settings
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy settings_delete on public.settings
  for delete using (auth.uid() = user_id);

-- =====================================================================
--  الصلاحيات — الزائر المجهول (anon) لا يلمس شيئًا
-- =====================================================================
revoke all on public.cases    from anon;
revoke all on public.settings from anon;

grant select, insert, update, delete on public.cases    to authenticated;
grant select, insert, update, delete on public.settings to authenticated;

-- =====================================================================
--  إغلاق باب: المالك لا يُنتحل ولو أُرسل user_id في الطلب
-- =====================================================================
create or replace function public.force_owner()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.user_id := auth.uid();
  return new;
end;
$$;

drop trigger if exists cases_force_owner    on public.cases;
drop trigger if exists settings_force_owner on public.settings;

create trigger cases_force_owner
  before insert or update on public.cases
  for each row execute function public.force_owner();

create trigger settings_force_owner
  before insert or update on public.settings
  for each row execute function public.force_owner();

-- =====================================================================
--  فحص سريع بعد التشغيل (اختياري)
-- =====================================================================
-- select tablename, rowsecurity from pg_tables
--   where schemaname='public' and tablename in ('cases','settings');
-- select tablename, policyname, cmd from pg_policies
--   where schemaname='public' order by tablename, policyname;

-- =====================================================================
--  تنظيف اختياري: امسح شواهد الحذف الأقدم من سنة
--  (شغّله يدويًا متى شئت — لا حاجة لجدولته)
-- =====================================================================
-- delete from public.cases
--   where deleted_at is not null and deleted_at < now() - interval '1 year';
