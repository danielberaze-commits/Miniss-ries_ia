import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return new Response('Unauthorized', { status: 401 });
  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !serviceRole) return new Response('Server not configured', { status: 500 });
  const userClient = createClient(url, anon, { auth: { persistSession: false } });
  const { data: { user }, error: authError } = await userClient.auth.getUser(token);
  if (authError || !user) return new Response('Unauthorized', { status: 401 });
  const admin = createClient(url, serviceRole, { auth: { persistSession: false } });
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) return new Response('Unable to delete account', { status: 500 });
  return Response.json({ deleted: true });
});
