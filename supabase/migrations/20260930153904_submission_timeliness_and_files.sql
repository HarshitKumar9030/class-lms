-- Determine timeliness on the server, regardless of the client's clock.
create function app_private.set_submission_status() returns trigger
language plpgsql security definer set search_path = '' as $$
declare deadline timestamptz;
begin
  select due_at into deadline from public.assignments where id = new.assignment_id;
  new.submitted_at := now();
  new.status := case when new.submitted_at > deadline then 'late'::public.submission_status else 'submitted'::public.submission_status end;
  return new;
end;
$$;
create trigger submission_timeliness before insert on public.assignment_submissions
for each row execute function app_private.set_submission_status();
revoke all on function app_private.set_submission_status() from public;

create policy submission_files_delete on storage.objects for delete to authenticated
using (bucket_id = 'submissions' and split_part(name, '/', 1) = (select auth.uid())::text);

create policy assignment_files_read on storage.objects for select to authenticated
using (bucket_id = 'resources' and exists(select 1 from public.assignments where name = any(attachment_paths)));
create policy assignment_files_insert on storage.objects for insert to authenticated
with check (bucket_id = 'resources' and (select app_private.is_staff()) and exists(select 1 from public.assignments where name = any(attachment_paths) and created_by = (select auth.uid())));
