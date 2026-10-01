-- Direct announcements take precedence over batch targeting. Empty recipients
-- retain the existing batch audience behavior.
alter table public.announcements
  add column recipient_ids uuid[] not null default '{}';
create index announcements_recipients_idx
  on public.announcements using gin (recipient_ids);

drop policy announcements_read on public.announcements;
create policy announcements_read on public.announcements
  for select to authenticated
  using (
    (select app_private.is_staff())
    or (
      is_published
      and (
        (cardinality(recipient_ids) > 0 and (select auth.uid()) = any(recipient_ids))
        or (cardinality(recipient_ids) = 0 and (select app_private.can_read_batches(batch_ids)))
      )
    )
  );

-- Teachers and admins need these rows to calculate resource engagement.
create policy resource_progress_staff_read on public.resource_progress
  for select to authenticated
  using ((select app_private.is_staff()));
