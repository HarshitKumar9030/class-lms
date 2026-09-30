create function public.get_saved_quiz_answers(target_attempt_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare result jsonb;
begin
  if (select auth.uid()) is null or not exists(
    select 1 from public.quiz_attempts
    where id = target_attempt_id and student_id = (select auth.uid())
  ) then raise exception 'Attempt unavailable'; end if;
  select coalesce(jsonb_object_agg(answer.question_id::text,
    jsonb_build_object('option_ids', answer.selected_option_ids,
      'response_text', answer.answer_text, 'flagged', answer.is_flagged)), '{}'::jsonb)
  into result from public.quiz_answers answer where answer.attempt_id = target_attempt_id;
  return result;
end;
$$;
revoke execute on function public.get_saved_quiz_answers(uuid) from anon, public;
grant execute on function public.get_saved_quiz_answers(uuid) to authenticated;
