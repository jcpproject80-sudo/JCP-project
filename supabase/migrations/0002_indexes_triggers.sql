-- INDEXES (speed up common queries)
CREATE INDEX idx_posts_status_created ON public.posts (status, created_at DESC);
CREATE INDEX idx_posts_slug ON public.posts (slug);
CREATE INDEX idx_comments_post_parent ON public.comments (post_id, parent_id);
CREATE INDEX idx_businesses_location ON public.businesses (latitude, longitude) WHERE is_verified = true;
CREATE INDEX idx_events_timeline ON public.events (start_time, end_time);

-- TRIGGER 1: Auto-create a profile row when a new user signs up via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, full_name, avatar_url, role)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'username', 'user_' || substring(md5(random()::text) from 1 for 8)),
        new.raw_user_meta_data->>'full_name',
        new.raw_user_meta_data->>'avatar_url',
        'user'
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- TRIGGER 2: Keep profiles.post_count in sync when posts are added/removed
CREATE OR REPLACE FUNCTION public.update_profile_post_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.profiles SET post_count = post_count + 1 WHERE id = NEW.author_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.profiles SET post_count = post_count - 1 WHERE id = OLD.author_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_post_count_sync
    AFTER INSERT OR DELETE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION public.update_profile_post_count();

-- TRIGGER 3: Keep posts.like_count in sync when likes are added/removed
CREATE OR REPLACE FUNCTION public.update_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.posts SET like_count = like_count - 1 WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_like_count_sync
    AFTER INSERT OR DELETE ON public.likes
    FOR EACH ROW EXECUTE FUNCTION public.update_post_like_count();