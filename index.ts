import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};
const reply = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { status, headers });

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers });
  if (req.method !== 'POST') return reply(405, { error: 'Método não permitido.' });

  const authorization = req.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return reply(401, { error: 'Entre na sua conta.' });
  const token = authorization.slice(7).trim();
  let body: Record<string, unknown>;
  try {
    const value: unknown = await req.json();
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw Error();
    body = value as Record<string, unknown>;
  } catch { return reply(400, { error: 'Requisição inválida.' }); }

  if (body.confirmation !== 'EXCLUIR MINHA CONTA' ||
      typeof body.code !== 'string' || !/^\d{6,8}$/.test(body.code.trim())) {
    return reply(400, { error: 'Confirmação e código de segurança obrigatórios.' });
  }

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) return reply(500, { error: 'Servidor não configurado.' });

  try {
    const auth = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: identity, error: identityError } = await auth.auth.getUser(token);
    const user = identity.user;
    if (identityError || !user || !user.email) return reply(401, { error: 'Sessão inválida.' });

    // Valida o código no servidor, e não apenas no aplicativo.
    const { data: verified, error: otpError } = await auth.auth.verifyOtp({
      email: user.email,
      token: body.code.trim(),
      type: 'email',
    });
    if (otpError || !verified.user || verified.user.id !== user.id) {
      return reply(403, { error: 'Código inválido ou expirado.' });
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    // ATENÇÃO: verificar dependências FK e política de remoção dos dados antes do deploy.
    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) {
      console.error('Erro ao excluir conta:', deleteError.message);
      return reply(500, { error: 'Não foi possível concluir a exclusão.' });
    }
    return reply(200, { success: true });
  } catch (error) {
    console.error('Erro inesperado:', error);
    return reply(500, { error: 'Falha temporária no servidor.' });
  }
});
