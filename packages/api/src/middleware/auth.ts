import { createMiddleware } from 'hono/factory';
import { getSupabaseClient } from '../db/supabase';

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

// Verifies the JWT and attaches the user + their role to the request context.
// Use this on any route that requires a logged-in user.
export const requireAuth = createMiddleware<{ Bindings: Bindings; Variables: Variables }>(
  async (c, next) => {
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

    // Fetch role from profiles table
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', data.user.id)
      .single();

    if (profileError || !profile) {
      return c.json({ success: false, message: 'Profile not found' }, 401);
    }

    // Attach the verified user to the context so route handlers can use c.get('user')
    c.set('user', {
      id: data.user.id,
      email: data.user.email,
      role: profile.role,
    });

    await next();
  }
);

// Use AFTER requireAuth on routes that need a specific role (e.g. admin-only)
export const requireRole = (...allowedRoles: string[]) => {
  return createMiddleware<{ Bindings: Bindings; Variables: Variables }>(async (c, next) => {
    const user = c.get('user');

    if (!user || !allowedRoles.includes(user.role)) {
      return c.json({ success: false, message: 'Forbidden: insufficient permissions' }, 403);
    }

    await next();
  });
};