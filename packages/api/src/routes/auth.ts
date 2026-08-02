import { Hono } from 'hono';
import { getSupabaseClient } from '../db/supabase';

type Bindings = {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
};

const auth = new Hono<{ Bindings: Bindings }>();

// POST /auth/signup
auth.post('/signup', async (c) => {
  const { email, password, username } = await c.req.json();

  if (!email || !password || !username) {
    return c.json({ success: false, message: 'email, password, and username are required' }, 400);
  }

  const supabase = getSupabaseClient(c.env);

  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: { username }, // this gets picked up by your handle_new_user() trigger
    },
  });

  if (error) {
    return c.json({ success: false, message: error.message }, 400);
  }

  return c.json({
    success: true,
    data: { user: data.user, session: data.session },
    message: 'Signup successful. Check email for verification if required.',
  });
});

// POST /auth/login
auth.post('/login', async (c) => {
  const { email, password } = await c.req.json();

  if (!email || !password) {
    return c.json({ success: false, message: 'email and password are required' }, 400);
  }

  const supabase = getSupabaseClient(c.env);

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    return c.json({ success: false, message: error.message }, 401);
  }

  return c.json({
    success: true,
    data: { user: data.user, session: data.session },
    message: 'Login successful',
  });
});

// GET /auth/me  (temporary version — no middleware yet, expects token in header manually)
auth.get('/me', async (c) => {
  const authHeader = c.req.header('Authorization');
  const token = authHeader?.replace('Bearer ', '');

  if (!token) {
    return c.json({ success: false, message: 'No token provided' }, 401);
  }

  const supabase = getSupabaseClient(c.env);
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    return c.json({ success: false, message: 'Invalid or expired token' }, 401);
  }

  // Fetch their profile too
  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', data.user.id)
    .single();

  return c.json({ success: true, data: { user: data.user, profile } });
});

export default auth;