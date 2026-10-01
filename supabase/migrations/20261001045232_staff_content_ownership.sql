-- Teachers manage content they authored; admins can manage all content.
-- Existing read policies continue to show all content to staff.
do $$
declare item record;
begin
  for item in select * from (values
    ('resources', 'created_by', 'resources_staff_all'),
    ('announcements', 'author_id', 'announcements_staff_all'),
    ('schedule_events', 'created_by', 'schedule_staff_all'),
    ('quizzes', 'created_by', 'quizzes_staff_all'),
    ('assignments', 'created_by', 'assignments_staff_all')
  ) as owners(table_name, owner_column, old_policy)
  loop
    execute format('drop policy %I on public.%I', item.old_policy, item.table_name);
    execute format(
      'create policy %I on public.%I for insert to authenticated with check ((select app_private.is_staff()) and %I = (select auth.uid()))',
      item.table_name || '_staff_insert', item.table_name, item.owner_column
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using ((select app_private.is_admin()) or %I = (select auth.uid())) with check ((select app_private.is_staff()) and ((select app_private.is_admin()) or %I = (select auth.uid())))',
      item.table_name || '_staff_update', item.table_name, item.owner_column, item.owner_column
    );
    execute format(
      'create policy %I on public.%I for delete to authenticated using ((select app_private.is_admin()) or %I = (select auth.uid()))',
      item.table_name || '_staff_delete', item.table_name, item.owner_column
    );
  end loop;
end $$;

drop policy questions_staff_all on public.quiz_questions;
create policy questions_staff_read on public.quiz_questions for select to authenticated
  using ((select app_private.is_staff()));
create policy questions_author_insert on public.quiz_questions for insert to authenticated
  with check (exists(select 1 from public.quizzes q where q.id = quiz_id
    and (q.created_by = (select auth.uid()) or (select app_private.is_admin()))));
create policy questions_author_update on public.quiz_questions for update to authenticated
  using (exists(select 1 from public.quizzes q where q.id = quiz_id
    and (q.created_by = (select auth.uid()) or (select app_private.is_admin()))))
  with check (exists(select 1 from public.quizzes q where q.id = quiz_id
    and (q.created_by = (select auth.uid()) or (select app_private.is_admin()))));
create policy questions_author_delete on public.quiz_questions for delete to authenticated
  using (exists(select 1 from public.quizzes q where q.id = quiz_id
    and (q.created_by = (select auth.uid()) or (select app_private.is_admin()))));

drop policy options_staff_all on public.quiz_options;
create policy options_staff_read on public.quiz_options for select to authenticated
  using ((select app_private.is_staff()));
create policy options_author_insert on public.quiz_options for insert to authenticated
  with check (exists(select 1 from public.quiz_questions question
    join public.quizzes quiz on quiz.id = question.quiz_id
    where question.id = question_id
      and (quiz.created_by = (select auth.uid()) or (select app_private.is_admin()))));
create policy options_author_update on public.quiz_options for update to authenticated
  using (exists(select 1 from public.quiz_questions question
    join public.quizzes quiz on quiz.id = question.quiz_id
    where question.id = question_id
      and (quiz.created_by = (select auth.uid()) or (select app_private.is_admin()))))
  with check (exists(select 1 from public.quiz_questions question
    join public.quizzes quiz on quiz.id = question.quiz_id
    where question.id = question_id
      and (quiz.created_by = (select auth.uid()) or (select app_private.is_admin()))));
create policy options_author_delete on public.quiz_options for delete to authenticated
  using (exists(select 1 from public.quiz_questions question
    join public.quizzes quiz on quiz.id = question.quiz_id
    where question.id = question_id
      and (quiz.created_by = (select auth.uid()) or (select app_private.is_admin()))));

drop policy resource_files_delete on storage.objects;
create policy resource_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'resources' and exists(
    select 1 from public.resources r where r.storage_path = name
      and (r.created_by = (select auth.uid()) or (select app_private.is_admin()))
  ));
