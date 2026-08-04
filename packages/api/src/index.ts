import { Hono } from 'hono';
import auth from './routes/auth';
import testRoutes from './routes/test';


type Bindings = {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
};

const app = new Hono<{ Bindings: Bindings }>();

app.get('/', (c) => c.text('Hello Hono!'));

app.route('/auth', auth);
 app.route('/test', testRoutes);
export default app;