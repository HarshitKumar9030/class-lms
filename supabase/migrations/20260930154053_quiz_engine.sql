-- Students never select answer keys directly. These narrowly scoped RPCs
-- validate the authenticated user before accessing protected quiz tables.

create function public.start_quiz_attempt(target_quiz_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  student uuid := (select auth.uid());
  quiz_row public.quizzes%rowtype;
  existing_id uuid;
  new_id uuid;
begin
  if student is null then raise exception 'Sign in to start a quiz'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(student::text || target_quiz_id::text, 0));
  select * into quiz_row from public.quizzes where id = target_quiz_id;
  if not found or not quiz_row.is_published or not app_private.can_read_batches(quiz_row.batch_ids) then
    raise exception 'Quiz is unavailable';
  end if;
  if (quiz_row.opens_at is not null and now() < quiz_row.opens_at)
    or (quiz_row.closes_at is not null and now() >= quiz_row.closes_at) then
    raise exception 'Quiz is not open';
  end if;
  select id into existing_id from public.quiz_attempts
    where quiz_id = target_quiz_id and student_id = student and submitted_at is null
    order by started_at desc limit 1;
  if existing_id is not null then return existing_id; end if;
  if (select count(*) from public.quiz_attempts where quiz_id = target_quiz_id and student_id = student) >= quiz_row.attempt_limit then
    raise exception 'Attempt limit reached';
  end if;
  insert into public.quiz_attempts(quiz_id, student_id) values (target_quiz_id, student) returning id into new_id;
  return new_id;
end;
$$;

create function public.get_quiz_questions(target_attempt_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  attempt_row public.quiz_attempts%rowtype;
  quiz_row public.quizzes%rowtype;
  result jsonb;
begin
  if (select auth.uid()) is null then raise exception 'Sign in to view quiz'; end if;
  select * into attempt_row from public.quiz_attempts where id = target_attempt_id and student_id = (select auth.uid());
  if not found then raise exception 'Attempt unavailable'; end if;
  select * into quiz_row from public.quizzes where id = attempt_row.quiz_id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', question.id, 'kind', question.kind, 'prompt', question.prompt, 'marks', question.marks,
    'options', (select coalesce(jsonb_agg(jsonb_build_object('id', option_row.id, 'label', option_row.label)
      order by case when quiz_row.shuffle_options then md5(option_row.id::text || target_attempt_id::text)
        else lpad(option_row.sort_order::text, 12, '0') end), '[]'::jsonb)
      from public.quiz_options option_row where option_row.question_id = question.id)
  ) order by case when quiz_row.shuffle_questions then md5(question.id::text || target_attempt_id::text)
      else lpad(question.sort_order::text, 12, '0') end), '[]'::jsonb) into result
  from public.quiz_questions question where question.quiz_id = attempt_row.quiz_id;
  return result;
end;
$$;

create function public.save_quiz_answer(target_attempt_id uuid, target_question_id uuid,
  option_ids uuid[] default '{}', response_text text default null, flagged boolean default false) returns void
language plpgsql security definer set search_path = '' as $$
declare
  attempt_row public.quiz_attempts%rowtype;
  duration_minutes integer;
begin
  if (select auth.uid()) is null then raise exception 'Sign in to answer'; end if;
  select * into attempt_row from public.quiz_attempts where id = target_attempt_id and student_id = (select auth.uid()) for update;
  if not found or attempt_row.submitted_at is not null then raise exception 'Attempt is unavailable'; end if;
  select q.duration_minutes into duration_minutes from public.quizzes q where q.id = attempt_row.quiz_id;
  if duration_minutes is not null and now() >= attempt_row.started_at + make_interval(mins => duration_minutes) then
    raise exception 'Time is up';
  end if;
  if not exists(select 1 from public.quiz_questions where id = target_question_id and quiz_id = attempt_row.quiz_id) then
    raise exception 'Question is unavailable';
  end if;
  if exists(select 1 from unnest(option_ids) answer_id
    left join public.quiz_options option_row on option_row.id = answer_id and option_row.question_id = target_question_id
    where option_row.id is null) then raise exception 'Invalid option'; end if;
  if length(coalesce(response_text, '')) > 4000 then raise exception 'Answer is too long'; end if;
  insert into public.quiz_answers(attempt_id, question_id, selected_option_ids, answer_text, is_flagged)
  values (target_attempt_id, target_question_id, option_ids, response_text, flagged)
  on conflict (attempt_id, question_id) do update set
    selected_option_ids = excluded.selected_option_ids, answer_text = excluded.answer_text,
    is_flagged = excluded.is_flagged, updated_at = now();
end;
$$;

create function public.submit_quiz_attempt(target_attempt_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  attempt_row public.quiz_attempts%rowtype;
  question_row public.quiz_questions%rowtype;
  answer_row public.quiz_answers%rowtype;
  correct_options uuid[];
  selected_options uuid[];
  awarded numeric(8,2);
  total numeric(8,2) := 0;
  score_total numeric(8,2) := 0;
  correct_count integer := 0;
  incorrect_count integer := 0;
  unanswered_count integer := 0;
begin
  if (select auth.uid()) is null then raise exception 'Sign in to submit'; end if;
  select * into attempt_row from public.quiz_attempts where id = target_attempt_id and student_id = (select auth.uid()) for update;
  if not found then raise exception 'Attempt unavailable'; end if;
  if attempt_row.submitted_at is not null then
    return jsonb_build_object('score', attempt_row.score, 'submitted_at', attempt_row.submitted_at);
  end if;
  for question_row in select * from public.quiz_questions where quiz_id = attempt_row.quiz_id loop
    total := total + question_row.marks;
    select * into answer_row from public.quiz_answers where attempt_id = target_attempt_id and question_id = question_row.id;
    if not found or (cardinality(answer_row.selected_option_ids) = 0 and nullif(trim(answer_row.answer_text), '') is null) then
      unanswered_count := unanswered_count + 1;
      continue;
    end if;
    awarded := 0;
    if question_row.kind in ('single_choice', 'multiple_choice', 'true_false') then
      select coalesce(array_agg(id order by id), '{}'::uuid[]) into correct_options
        from public.quiz_options where question_id = question_row.id and is_correct;
      select coalesce(array_agg(distinct id order by id), '{}'::uuid[]) into selected_options
        from unnest(answer_row.selected_option_ids) id;
      if correct_options = selected_options and cardinality(correct_options) > 0 then awarded := question_row.marks; end if;
    elsif question_row.kind in ('one_word', 'fill_blank') then
      if lower(trim(coalesce(answer_row.answer_text, ''))) = lower(trim(coalesce(question_row.answer_text, '')))
        and nullif(trim(coalesce(question_row.answer_text, '')), '') is not null then awarded := question_row.marks; end if;
    elsif question_row.kind = 'short_answer' then
      awarded := null; -- Teacher grades these later.
    end if;
    update public.quiz_answers set awarded_marks = awarded where attempt_id = target_attempt_id and question_id = question_row.id;
    if awarded = question_row.marks then correct_count := correct_count + 1;
    elsif awarded is not null then incorrect_count := incorrect_count + 1; end if;
    score_total := score_total + coalesce(awarded, 0);
  end loop;
  update public.quiz_attempts set score = score_total, submitted_at = now() where id = target_attempt_id;
  return jsonb_build_object('score', score_total, 'total', total, 'correct', correct_count,
    'incorrect', incorrect_count, 'unanswered', unanswered_count, 'submitted_at', now());
end;
$$;

create function public.get_quiz_result(target_attempt_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  attempt_row public.quiz_attempts%rowtype;
  quiz_row public.quizzes%rowtype;
  total_marks numeric(8,2);
  correct_count integer;
  incorrect_count integer;
  unanswered_count integer;
  pending_count integer;
  review_items jsonb;
begin
  if (select auth.uid()) is null then raise exception 'Sign in to view results'; end if;
  select * into attempt_row from public.quiz_attempts where id = target_attempt_id and student_id = (select auth.uid());
  if not found or attempt_row.submitted_at is null then raise exception 'Result unavailable'; end if;
  select * into quiz_row from public.quizzes where id = attempt_row.quiz_id;
  select coalesce(sum(question.marks), 0),
    count(*) filter (where answer.attempt_id is not null and answer.awarded_marks = question.marks),
    count(*) filter (where answer.awarded_marks = 0 and (cardinality(answer.selected_option_ids) > 0 or nullif(trim(answer.answer_text), '') is not null)),
    count(*) filter (where answer.attempt_id is null or (cardinality(answer.selected_option_ids) = 0 and nullif(trim(answer.answer_text), '') is null)),
    count(*) filter (where answer.attempt_id is not null and answer.awarded_marks is null and (cardinality(answer.selected_option_ids) > 0 or nullif(trim(answer.answer_text), '') is not null))
  into total_marks, correct_count, incorrect_count, unanswered_count, pending_count
  from public.quiz_questions question
  left join public.quiz_answers answer on answer.question_id = question.id and answer.attempt_id = target_attempt_id
  where question.quiz_id = attempt_row.quiz_id;
  if quiz_row.show_answers_after_submission then
    select coalesce(jsonb_agg(jsonb_build_object(
      'prompt', question.prompt,
      'student_answer', answer.answer_text,
      'student_options', (select coalesce(jsonb_agg(option_row.label order by option_row.sort_order), '[]'::jsonb)
        from public.quiz_options option_row where option_row.id = any(answer.selected_option_ids)),
      'correct_answer', question.answer_text,
      'correct_options', (select coalesce(jsonb_agg(option_row.label order by option_row.sort_order), '[]'::jsonb)
        from public.quiz_options option_row where option_row.question_id = question.id and option_row.is_correct),
      'explanation', question.explanation,
      'awarded_marks', answer.awarded_marks,
      'marks', question.marks
    ) order by question.sort_order), '[]'::jsonb) into review_items
    from public.quiz_questions question
    left join public.quiz_answers answer on answer.question_id = question.id and answer.attempt_id = target_attempt_id
    where question.quiz_id = attempt_row.quiz_id;
  end if;
  return jsonb_build_object(
    'score', attempt_row.score, 'total', total_marks,
    'correct', correct_count, 'incorrect', incorrect_count,
    'unanswered', unanswered_count, 'pending', pending_count,
    'time_seconds', extract(epoch from attempt_row.submitted_at - attempt_row.started_at)::integer,
    'feedback', attempt_row.feedback,
    'review', review_items
  );
end;
$$;

revoke all on function public.start_quiz_attempt(uuid), public.get_quiz_questions(uuid),
  public.save_quiz_answer(uuid,uuid,uuid[],text,boolean), public.submit_quiz_attempt(uuid),
  public.get_quiz_result(uuid) from public;
grant execute on function public.start_quiz_attempt(uuid), public.get_quiz_questions(uuid),
  public.save_quiz_answer(uuid,uuid,uuid[],text,boolean), public.submit_quiz_attempt(uuid),
  public.get_quiz_result(uuid) to authenticated;
