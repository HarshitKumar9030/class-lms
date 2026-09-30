-- Core relational model. Run in a Supabase project before starting the app.
create extension if not exists pgcrypto;

create schema if not exists app_private;
grant usage on schema app_private to authenticated;

create type public.app_role as enum ('student', 'teacher', 'admin');
create type public.resource_kind as enum ('pdf', 'document', 'image', 'audio', 'video_link', 'web_link', 'worksheet', 'notes', 'presentation', 'vocabulary', 'grammar', 'literature');
create type public.schedule_kind as enum ('class', 'special', 'test', 'holiday');
create type public.schedule_status as enum ('scheduled', 'cancelled', 'rescheduled');
create type public.question_kind as enum ('single_choice', 'multiple_choice', 'true_false', 'one_word', 'fill_blank', 'short_answer');
create type public.submission_status as enum ('submitted', 'late', 'reviewed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role public.app_role not null default 'student',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.batches (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.batch_members (
  batch_id uuid not null references public.batches(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (batch_id, student_id)
);
create index batch_members_student_idx on public.batch_members(student_id);

create function app_private.create_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function app_private.create_profile();

create function app_private.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;

create function app_private.is_staff() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and role in ('teacher', 'admin'));
$$;
create function app_private.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and role = 'admin');
$$;
create function app_private.can_read_batches(target_ids uuid[]) returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.is_staff() or exists (
    select 1 from public.batch_members bm
    where bm.student_id = (select auth.uid())
      and (cardinality(target_ids) = 0 or bm.batch_id = any(target_ids))
  );
$$;

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.topics (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  parent_id uuid references public.topics(id) on delete cascade,
  title text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index topics_course_parent_idx on public.topics(course_id, parent_id, sort_order);

create table public.resources (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id),
  topic_id uuid references public.topics(id),
  title text not null,
  description text,
  kind public.resource_kind not null,
  storage_path text,
  external_url text,
  batch_ids uuid[] not null default '{}',
  is_published boolean not null default false,
  allow_download boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((storage_path is not null) <> (external_url is not null))
);
create index resources_course_topic_idx on public.resources(course_id, topic_id, created_at desc);
create index resources_batches_idx on public.resources using gin(batch_ids);
create table public.resource_progress (
  resource_id uuid not null references public.resources(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  position_seconds integer,
  page_number integer,
  last_opened_at timestamptz not null default now(),
  primary key (resource_id, student_id)
);
create table public.resource_bookmarks (
  resource_id uuid not null references public.resources(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (resource_id, student_id)
);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  priority smallint not null default 0 check(priority between 0 and 2),
  is_pinned boolean not null default false,
  attachment_paths text[] not null default '{}',
  batch_ids uuid[] not null default '{}',
  is_published boolean not null default false,
  author_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index announcements_feed_idx on public.announcements(is_published, is_pinned desc, created_at desc);
create index announcements_batches_idx on public.announcements using gin(batch_ids);
create table public.announcement_reads (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (announcement_id, student_id)
);

create table public.schedule_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  kind public.schedule_kind not null default 'class',
  status public.schedule_status not null default 'scheduled',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  recurrence_rule text,
  batch_ids uuid[] not null default '{}',
  location text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index schedule_events_starts_idx on public.schedule_events(starts_at);
create index schedule_events_batches_idx on public.schedule_events using gin(batch_ids);

create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  instructions text,
  duration_minutes integer check(duration_minutes > 0),
  opens_at timestamptz,
  closes_at timestamptz,
  attempt_limit integer not null default 1 check(attempt_limit > 0),
  passing_marks numeric(8,2) not null default 0,
  shuffle_questions boolean not null default false,
  shuffle_options boolean not null default false,
  show_answers_after_submission boolean not null default false,
  batch_ids uuid[] not null default '{}',
  is_published boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (closes_at is null or opens_at is null or closes_at > opens_at)
);
create index quizzes_batches_idx on public.quizzes using gin(batch_ids);
create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  kind public.question_kind not null,
  prompt text not null,
  marks numeric(8,2) not null default 1 check(marks > 0),
  answer_text text,
  explanation text,
  sort_order integer not null default 0
);
create index quiz_questions_quiz_idx on public.quiz_questions(quiz_id, sort_order);
create table public.quiz_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.quiz_questions(id) on delete cascade,
  label text not null,
  is_correct boolean not null default false,
  sort_order integer not null default 0
);
create index quiz_options_question_idx on public.quiz_options(question_id, sort_order);
create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id),
  student_id uuid not null references public.profiles(id),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  score numeric(8,2),
  feedback text,
  created_at timestamptz not null default now()
);
create index quiz_attempts_student_idx on public.quiz_attempts(student_id, started_at desc);
create table public.quiz_answers (
  attempt_id uuid not null references public.quiz_attempts(id) on delete cascade,
  question_id uuid not null references public.quiz_questions(id),
  selected_option_ids uuid[] not null default '{}',
  answer_text text,
  is_flagged boolean not null default false,
  awarded_marks numeric(8,2),
  updated_at timestamptz not null default now(),
  primary key (attempt_id, question_id)
);

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  instructions text not null,
  attachment_paths text[] not null default '{}',
  due_at timestamptz not null,
  maximum_marks numeric(8,2) check(maximum_marks > 0),
  batch_ids uuid[] not null default '{}',
  is_published boolean not null default false,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index assignments_due_idx on public.assignments(due_at);
create index assignments_batches_idx on public.assignments using gin(batch_ids);
create table public.assignment_submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.profiles(id),
  response_text text,
  attachment_paths text[] not null default '{}',
  status public.submission_status not null default 'submitted',
  submitted_at timestamptz not null default now(),
  marks numeric(8,2),
  feedback text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  unique (assignment_id, student_id)
);
create index assignment_submissions_student_idx on public.assignment_submissions(student_id);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  route text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_recipient_idx on public.notifications(recipient_id, created_at desc);

do $$ declare table_name text; begin
  foreach table_name in array array['profiles','batches','courses','topics','resources','announcements','schedule_events','quizzes','assignments'] loop
    execute format('create trigger %I before update on public.%I for each row execute function app_private.touch_updated_at()', 'touch_' || table_name, table_name);
  end loop;
end $$;

-- Policies are deliberately explicit. No anonymous access to application tables.
do $$ declare table_name text; begin
  foreach table_name in array array['profiles','batches','batch_members','courses','topics','resources','resource_progress','resource_bookmarks','announcements','announcement_reads','schedule_events','quizzes','quiz_questions','quiz_options','quiz_attempts','quiz_answers','assignments','assignment_submissions','notifications'] loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end $$;

create policy profiles_read on public.profiles for select to authenticated using (id = (select auth.uid()) or (select app_private.is_staff()));
create policy profiles_admin_write on public.profiles for update to authenticated using ((select app_private.is_admin())) with check ((select app_private.is_admin()));
create policy batches_read on public.batches for select to authenticated using ((select app_private.is_staff()) or exists(select 1 from public.batch_members where batch_id = batches.id and student_id = (select auth.uid())));
create policy batches_staff_insert on public.batches for insert to authenticated with check ((select app_private.is_staff()));
create policy batches_staff_update on public.batches for update to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()));
create policy batches_staff_delete on public.batches for delete to authenticated using ((select app_private.is_admin()));
create policy members_read on public.batch_members for select to authenticated using (student_id = (select auth.uid()) or (select app_private.is_staff()));
create policy members_admin_insert on public.batch_members for insert to authenticated with check ((select app_private.is_admin()));
create policy members_admin_delete on public.batch_members for delete to authenticated using ((select app_private.is_admin()));

create policy courses_read on public.courses for select to authenticated using ((select app_private.is_staff()) or exists(select 1 from public.batch_members where student_id = (select auth.uid())));
create policy courses_staff_all on public.courses for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()));
create policy topics_read on public.topics for select to authenticated using ((select app_private.is_staff()) or exists(select 1 from public.batch_members where student_id = (select auth.uid())));
create policy topics_staff_all on public.topics for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()));

create policy resources_read on public.resources for select to authenticated using ((select app_private.is_staff()) or (is_published and (select app_private.can_read_batches(batch_ids))));
create policy resources_staff_all on public.resources for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()) and created_by = (select auth.uid()));
create policy resource_progress_own on public.resource_progress for all to authenticated using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()) and exists(select 1 from public.resources where id = resource_id));
create policy resource_bookmarks_own on public.resource_bookmarks for all to authenticated using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()) and exists(select 1 from public.resources where id = resource_id));

create policy announcements_read on public.announcements for select to authenticated using ((select app_private.is_staff()) or (is_published and (select app_private.can_read_batches(batch_ids))));
create policy announcements_staff_all on public.announcements for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()) and author_id = (select auth.uid()));
create policy announcement_reads_own on public.announcement_reads for all to authenticated using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()) and exists(select 1 from public.announcements where id = announcement_id));
create policy schedule_read on public.schedule_events for select to authenticated using ((select app_private.can_read_batches(batch_ids)));
create policy schedule_staff_all on public.schedule_events for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()) and created_by = (select auth.uid()));

create policy quizzes_read on public.quizzes for select to authenticated using ((select app_private.is_staff()) or (is_published and (select app_private.can_read_batches(batch_ids))));
create policy quizzes_staff_all on public.quizzes for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()) and created_by = (select auth.uid()));
-- Answer keys live here. Students receive redacted questions via a later RPC.
create policy questions_staff_all on public.quiz_questions for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()));
create policy options_staff_all on public.quiz_options for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()));
create policy attempts_read on public.quiz_attempts for select to authenticated using (student_id = (select auth.uid()) or (select app_private.is_staff()));
create policy answers_read on public.quiz_answers for select to authenticated using ((select app_private.is_staff()));

create policy assignments_read on public.assignments for select to authenticated using ((select app_private.is_staff()) or (is_published and (select app_private.can_read_batches(batch_ids))));
create policy assignments_staff_all on public.assignments for all to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()) and created_by = (select auth.uid()));
create policy submissions_read on public.assignment_submissions for select to authenticated using (student_id = (select auth.uid()) or (select app_private.is_staff()));
create policy submissions_student_insert on public.assignment_submissions for insert to authenticated with check (student_id = (select auth.uid()) and status in ('submitted','late') and marks is null and feedback is null and reviewed_by is null and exists(select 1 from public.assignments where id = assignment_id));
create policy submissions_staff_update on public.assignment_submissions for update to authenticated using ((select app_private.is_staff())) with check ((select app_private.is_staff()));

create policy notifications_own_read on public.notifications for select to authenticated using (recipient_id = (select auth.uid()));
create policy notifications_own_update on public.notifications for update to authenticated using (recipient_id = (select auth.uid())) with check (recipient_id = (select auth.uid()));
create policy notifications_staff_insert on public.notifications for insert to authenticated with check ((select app_private.is_staff()));

-- Restrict column-level updates that could otherwise change ownership or grading.
do $$ declare table_name text; begin
  foreach table_name in array array['profiles','batches','batch_members','courses','topics','resources','resource_progress','resource_bookmarks','announcements','announcement_reads','schedule_events','quizzes','quiz_questions','quiz_options','quiz_attempts','quiz_answers','assignments','assignment_submissions','notifications'] loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', table_name);
  end loop;
end $$;
revoke all on all functions in schema app_private from public;
grant execute on function app_private.is_staff(), app_private.is_admin(), app_private.can_read_batches(uuid[]) to authenticated;
revoke update on public.profiles from authenticated;
grant update (full_name, avatar_path, role) on public.profiles to authenticated;
-- Only admins satisfy the update policy; users cannot promote themselves.
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

insert into storage.buckets(id, name, public) values ('resources', 'resources', false), ('submissions', 'submissions', false) on conflict (id) do nothing;

create policy resource_files_read on storage.objects for select to authenticated
using (bucket_id = 'resources' and exists(select 1 from public.resources where storage_path = name));
create policy resource_files_insert on storage.objects for insert to authenticated
with check (bucket_id = 'resources' and (select app_private.is_staff()) and exists(select 1 from public.resources where storage_path = name and created_by = (select auth.uid())));
create policy resource_files_delete on storage.objects for delete to authenticated
using (bucket_id = 'resources' and (select app_private.is_staff()) and exists(select 1 from public.resources where storage_path = name and created_by = (select auth.uid())));
create policy submission_files_read on storage.objects for select to authenticated
using (bucket_id = 'submissions' and (split_part(name, '/', 1) = (select auth.uid())::text or ((select app_private.is_staff()) and exists(select 1 from public.assignment_submissions where name = any(attachment_paths)))));
create policy submission_files_insert on storage.objects for insert to authenticated
with check (bucket_id = 'submissions' and split_part(name, '/', 1) = (select auth.uid())::text);

