-- Staff access is assigned only after Supabase verifies the account email.
-- Client-supplied metadata never controls roles.
create or replace function app_private.create_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    case
      when new.email_confirmed_at is not null and lower(new.email) = 'harshitkumar9030@gmail.com' then 'admin'::public.app_role
      when new.email_confirmed_at is not null and lower(new.email) = 'sharmashriju14@gmail.com' then 'teacher'::public.app_role
      else 'student'::public.app_role
    end
  );
  return new;
end;
$$;

create function app_private.sync_verified_staff_role() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if lower(coalesce(new.email, '')) in ('harshitkumar9030@gmail.com', 'sharmashriju14@gmail.com')
     or lower(coalesce(old.email, '')) in ('harshitkumar9030@gmail.com', 'sharmashriju14@gmail.com') then
    update public.profiles
    set role = case
      when new.email_confirmed_at is not null and lower(new.email) = 'harshitkumar9030@gmail.com' then 'admin'::public.app_role
      when new.email_confirmed_at is not null and lower(new.email) = 'sharmashriju14@gmail.com' then 'teacher'::public.app_role
      else 'student'::public.app_role
    end
    where id = new.id;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_staff_role
after update of email, email_confirmed_at on auth.users
for each row execute function app_private.sync_verified_staff_role();

update public.profiles p
set role = case
  when lower(u.email) = 'harshitkumar9030@gmail.com' then 'admin'::public.app_role
  else 'teacher'::public.app_role
end
from auth.users u
where p.id = u.id
  and u.email_confirmed_at is not null
  and lower(u.email) in ('harshitkumar9030@gmail.com', 'sharmashriju14@gmail.com');

revoke all on function app_private.sync_verified_staff_role() from public, anon, authenticated;
