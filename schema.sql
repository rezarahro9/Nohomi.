-- Run in Supabase SQL Editor for Nahomino 4. This creates tables and storage policies.
-- Run once in Supabase SQL Editor. Auth users register with email/password.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'دانش‌آموز',
 role text not null default 'student' check(role in ('student','teacher','admin')),
 created_at timestamptz not null default now()
);
create or replace function public.new_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,display_name,role) values(new.id, coalesce(nullif(new.raw_user_meta_data->>'display_name',''),'دانش‌آموز'),'student'); return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.new_profile();
create or replace function public.my_role() returns text language sql stable security definer set search_path=public as $$ select coalesce((select role from public.profiles where id=auth.uid()),'guest') $$;
revoke all on function public.my_role() from public;
grant execute on function public.my_role() to authenticated,anon;

create table if not exists public.posts (
 id uuid primary key default gen_random_uuid(), subject text not null,
 section text not null check(section in ('text','sample','notes','homework','special')),
 title text not null, body text not null default '',
 files jsonb not null default '[]'::jsonb,
 status text not null default 'draft' check(status in ('draft','published')),
 author uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.exams (
 id uuid primary key default gen_random_uuid(), subject text not null,
 title text not null, questions jsonb not null default '[]'::jsonb,
 status text not null default 'draft' check(status in ('draft','published')),
 author uuid not null default auth.uid() references auth.users(id),
 created_at timestamptz not null default now()
);
-- Answers must never be in exams.questions. Stored in a separately protected table.
create table if not exists public.exam_keys (
 exam_id uuid primary key references public.exams(id) on delete cascade,
 answer_key jsonb not null default '[]'::jsonb
);
create table if not exists public.attempts (
 id uuid primary key default gen_random_uuid(),
 exam_id uuid not null references public.exams(id) on delete cascade,
 student_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 answers jsonb not null,
 score numeric(5,2) not null default 0,
 total integer not null default 0,
 submitted_at timestamptz not null default now(),
 unique(exam_id,student_id)
);
create table if not exists public.ai_usage (
 user_id uuid not null references auth.users(id) on delete cascade,
 usage_date date not null default current_date,
 count integer not null default 0,
 primary key(user_id,usage_date)
);

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.exams enable row level security;
alter table public.exam_keys enable row level security;
alter table public.attempts enable row level security;
alter table public.ai_usage enable row level security;

create policy "profiles self or admin" on public.profiles for select to authenticated using (id=auth.uid() or public.my_role()='admin');
create policy "posts select published or staff" on public.posts for select to anon,authenticated using (status='published' or public.my_role() in ('teacher','admin'));
create policy "posts staff insert" on public.posts for insert to authenticated with check (public.my_role()='admin' and author=auth.uid());
create policy "posts staff update" on public.posts for update to authenticated using (public.my_role()='admin') with check (public.my_role()='admin');
create policy "posts staff delete" on public.posts for delete to authenticated using (public.my_role()='admin');
create policy "exams published or staff" on public.exams for select to anon,authenticated using (status='published' or public.my_role() in ('teacher','admin'));
create policy "exams staff insert" on public.exams for insert to authenticated with check(public.my_role()='admin' and author=auth.uid());
create policy "exams staff update" on public.exams for update to authenticated using(public.my_role()='admin') with check(public.my_role()='admin');
create policy "exams staff delete" on public.exams for delete to authenticated using(public.my_role()='admin');
create policy "keys staff read" on public.exam_keys for select to authenticated using(public.my_role()='admin' or (public.my_role()='teacher' and exists(select 1 from public.exams where id=exam_id and author=auth.uid())));
create policy "keys staff insert" on public.exam_keys for insert to authenticated with check(public.my_role()='admin' or (public.my_role()='teacher' and exists(select 1 from public.exams where id=exam_id and author=auth.uid())));
create policy "keys staff update" on public.exam_keys for update to authenticated using(public.my_role()='admin' or (public.my_role()='teacher' and exists(select 1 from public.exams where id=exam_id and author=auth.uid())));
create policy "attempts own or staff read" on public.attempts for select to authenticated using(student_id=auth.uid() or public.my_role()='admin' or (public.my_role()='teacher' and exists(select 1 from public.exams where id=exam_id and author=auth.uid())));

-- Atomic, one-attempt, multiple-choice grading; student never gets the answer key.
create or replace function public.submit_exam(p_exam uuid,p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare e public.exams%rowtype; keys jsonb; idx int; points int:=0; max_points int:=0; answer text; correct text;
begin
 if auth.uid() is null then raise exception 'ورود لازم است'; end if;
 select * into e from public.exams where id=p_exam and status='published';
 if not found then raise exception 'امتحان قابل دسترسی نیست'; end if;
 if jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers)<>jsonb_array_length(e.questions) then raise exception 'تعداد پاسخ‌ها درست نیست'; end if;
 select answer_key into keys from public.exam_keys where exam_id=p_exam;
 if keys is null or jsonb_array_length(keys)<>jsonb_array_length(e.questions) then raise exception 'پاسخنامه ناقص است'; end if;
 for idx in 0..jsonb_array_length(e.questions)-1 loop
   if (e.questions->idx->>'type')<>'mcq' then raise exception 'نسخه اولیه فقط آزمون چهارگزینه‌ای را خودکار تصحیح می‌کند'; end if;
   max_points:=max_points+1;
   answer:=p_answers->>idx; correct:=keys->>idx;
   if answer=correct then points:=points+1; end if;
 end loop;
 insert into public.attempts(exam_id,student_id,answers,score,total) values(p_exam,auth.uid(),p_answers,points,max_points);
 return jsonb_build_object('score',points,'total',max_points);
exception when unique_violation then raise exception 'این امتحان را قبلاً داده‌اید';
end $$;
revoke all on function public.submit_exam(uuid,jsonb) from public;
grant execute on function public.submit_exam(uuid,jsonb) to authenticated;

-- Secure, atomic daily quota; only backend's privileged key may call.
create or replace function public.bump_ai_usage(p_user uuid,p_daily_limit integer default 10)
returns boolean language plpgsql security definer set search_path=public as $$
declare n integer;
begin
 insert into public.ai_usage(user_id,usage_date,count) values(p_user,current_date,1)
 on conflict(user_id,usage_date) do update set count=ai_usage.count+1
 returning count into n;
 return n<=p_daily_limit;
end $$;
revoke all on function public.bump_ai_usage(uuid,integer) from public,anon,authenticated;
grant execute on function public.bump_ai_usage(uuid,integer) to service_role;

-- Public teaching attachments bucket: upload restricted to staff; do not upload private/student data.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
('teaching','teaching',true,20971520,array['application/pdf','image/png','image/jpeg','image/webp','video/mp4','text/plain','text/csv','text/markdown','application/json','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation'])
on conflict(id) do nothing;
create policy "staff upload teaching" on storage.objects for insert to authenticated with check(bucket_id='teaching' and public.my_role() in ('teacher','admin'));
create policy "public teaching read" on storage.objects for select to anon,authenticated using(bucket_id='teaching');

-- IMPORTANT: promote only your real registered account, after signup, by replacing the email:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='YOUR_EMAIL');
-- To authorize a teacher repeat with role='teacher' and the teacher email.

-- Expand existing posts section constraint if upgrading from previous schema
alter table public.posts drop constraint if exists posts_section_check;
alter table public.posts add constraint posts_section_check check (section in ('text','sample','notes','homework','special'));
-- Storage is public for downloadable educational files; uploads ONLY admin.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('learning-files','learning-files',true,20971520,null)
on conflict(id) do update set public=true, file_size_limit=20971520;
create policy "public educational attachments" on storage.objects for select to anon,authenticated using(bucket_id='learning-files');
create policy "admin upload attachments" on storage.objects for insert to authenticated with check(bucket_id='learning-files' and public.my_role()='admin');
create policy "admin delete attachments" on storage.objects for delete to authenticated using(bucket_id='learning-files' and public.my_role()='admin');
-- ADMIN BOOTSTRAP: register via Auth, copy your user UUID from Auth > Users, then execute as owner:
-- update public.profiles set role='admin' where id='YOUR-AUTH-USER-UUID';
-- Never paste a password into SQL or client-side code.
