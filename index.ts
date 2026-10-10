import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers });
  if (req.method !== 'POST') return reply(405, { error: 'Método não permitido.' });

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return reply(401, { error: 'Faça login para continuar.' });
  }
  const token = authHeader.slice(7).trim();
  if (!token) return reply(401, { error: 'Token ausente.' });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: 'Dados inválidos.' });
  }
  if (
    typeof body !== 'object' || body === null ||
    (body as Record<string, unknown>).confirmation !== 'EXCLUIR MINHA CONTA'
  ) {
    return reply(400, { error: 'Confirmação de exclusão obrigatória.' });
  }

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) {
    console.error('Configuração Supabase incompleta.');
    return reply(500, { error: 'Serviço temporariamente indisponível.' });
  }

  try {
    const userClient = createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data, error: userError } = await userClient.auth.getUser(token);
    if (userError || !data.user) {
      return reply(401, { error: 'Sessão inválida ou expirada.' });
    }

    const admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // ATENÇÃO: antes de uso público, implementar reautenticação recente
    // e definir a política de remoção de dados associados ao usuário.
    const { error: deleteError } = await admin.auth.admin.deleteUser(data.user.id);
    if (deleteError) {
      console.error('Falha ao excluir usuário:', deleteError.message);
      return reply(500, { error: 'Não foi possível excluir a conta.' });
    }
    return reply(200, { success: true });
  } catch (error) {
    console.error('Falha inesperada na exclusão:', error);
    return reply(500, { error: 'Erro interno. Tente novamente.' });
  }
});
