-- Show a reliable account identifier in admin user management.
alter table public.profiles add column email text;
update public.profiles p set email = u.email
from auth.users u where u.id = p.id;

create or replace function app_private.sync_profile_email()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_profile
after update of email on auth.users
for each row execute function app_private.sync_profile_email();

create or replace function app_private.create_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    new.email,
    case
      when new.email_confirmed_at is not null and lower(new.email) = 'harshitkumar9030@gmail.com' then 'admin'::public.app_role
      when new.email_confirmed_at is not null and lower(new.email) = 'sharmashriju14@gmail.com' then 'teacher'::public.app_role
      else 'student'::public.app_role
    end
  );
  return new;
end;
$$;

revoke all on function app_private.sync_profile_email() from public, anon, authenticated;
