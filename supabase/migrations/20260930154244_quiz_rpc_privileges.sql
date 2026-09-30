-- Supabase's database default grants EXECUTE to anon explicitly.
-- These functions are authenticated RPCs and validate ownership internally.
revoke execute on function public.start_quiz_attempt(uuid), public.get_quiz_questions(uuid),
  public.save_quiz_answer(uuid,uuid,uuid[],text,boolean), public.submit_quiz_attempt(uuid),
  public.get_quiz_result(uuid) from anon, public;

-- This project-managed event trigger function is never a client RPC.
revoke execute on function public.rls_auto_enable() from anon, authenticated, public;
