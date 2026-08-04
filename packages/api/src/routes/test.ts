import { Hono } from 'hono';
import { requireAuth, requireRole } from '../middleware/auth';

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

const testRoutes = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Anyone logged in can access this
testRoutes.get('/any-user', requireAuth, async (c) => {
  const user = c.get('user');
  return c.json({ success: true, message: `Hello ${user.email}, you're logged in as ${user.role}` });
});

// ONLY admins can access this
testRoutes.get('/admin-only', requireAuth, requireRole('admin'), async (c) => {
  const user = c.get('user');
  return c.json({ success: true, message: `Welcome admin ${user.email}` });
});

export default testRoutes;