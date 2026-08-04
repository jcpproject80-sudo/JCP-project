import { Hono } from 'hono';
import { getSupabaseClient } from '../db/supabase';
import { requireAuth } from '../middleware/auth';

type Bindings = {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
};

type Variables = {
  user: {
    id: string;
    email: string | undefined;
    role: string;
  };
};

const auth = new Hono<{ Bindings: Bindings; Variables: Variables }>();

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
      data: { username },
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

// GET /auth/me — now protected by middleware instead of manual checks
auth.get('/me', requireAuth, async (c) => {
  const authUser = c.get('user'); // set by requireAuth middleware
  const supabase = getSupabaseClient(c.env);

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', authUser.id)
    .single();

  return c.json({ success: true, data: { user: authUser, profile } });
});

export default auth;