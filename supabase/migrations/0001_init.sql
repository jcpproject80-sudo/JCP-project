-- ENUMS
CREATE TYPE user_role AS ENUM ('guest', 'user', 'moderator', 'admin');
CREATE TYPE post_status AS ENUM ('draft', 'under_moderation', 'published', 'rejected');
CREATE TYPE entity_category AS ENUM ('culture', 'food', 'tourism', 'event', 'business');

-- 1. USERS PROFILE (Linked to auth.users)
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    username TEXT UNIQUE NOT NULL CONSTRAINT username_length_check CHECK (char_length(username) >= 3),
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    role user_role DEFAULT 'user'::user_role NOT NULL,
    post_count INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- 2. CATEGORIES Table
CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    type entity_category NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Categories read access to everyone" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Categories write access to Admin only" ON public.categories FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
);

-- 3. POSTS Table
CREATE TABLE public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE RESTRICT,
    title TEXT NOT NULL CONSTRAINT title_length_check CHECK (char_length(title) >= 5),
    slug TEXT NOT NULL UNIQUE,
    content_json JSONB NOT NULL, -- TipTap/EditorJS JSON structure
    summary TEXT NOT NULL,
    featured_image_url TEXT,
    gallery_urls TEXT[] DEFAULT '{}'::TEXT[],
    status post_status DEFAULT 'published'::post_status NOT NULL,
    view_count INTEGER DEFAULT 0 NOT NULL,
    like_count INTEGER DEFAULT 0 NOT NULL,
    comment_count INTEGER DEFAULT 0 NOT NULL,
    is_featured BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Published posts are viewable by everyone" ON public.posts
    FOR SELECT USING (status = 'published');

CREATE POLICY "Users can view their own drafts/rejected posts" ON public.posts
    FOR SELECT USING (auth.uid() = author_id);

CREATE POLICY "Moderators and Admins can view all posts" ON public.posts
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role IN ('moderator', 'admin'))
    );

CREATE POLICY "Users can insert their own posts" ON public.posts
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own posts" ON public.posts
    FOR UPDATE USING (auth.uid() = author_id) WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can delete their own posts" ON public.posts
    FOR DELETE USING (auth.uid() = author_id);

CREATE POLICY "Moderators/Admins can update status of posts" ON public.posts
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role IN ('moderator', 'admin'))
    );

-- 4. COMMENTS Table
CREATE TABLE public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    content TEXT NOT NULL CONSTRAINT comment_length_check CHECK (char_length(content) >= 1),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Comments are public" ON public.comments FOR SELECT USING (true);
CREATE POLICY "Users can post comments" ON public.comments FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Users can delete own comments" ON public.comments FOR DELETE USING (auth.uid() = author_id);

-- 5. LIKES Table (Unique pair constraint)
CREATE TABLE public.likes (
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    PRIMARY KEY (post_id, user_id)
);

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Likes can be viewed by anyone" ON public.likes FOR SELECT USING (true);
CREATE POLICY "Users can toggles likes" ON public.likes FOR ALL USING (auth.uid() = user_id);

-- 6. BUSINESS LISTINGS Table
CREATE TABLE public.businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    address TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    website TEXT,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    logo_url TEXT,
    cover_image_url TEXT,
    is_verified BOOLEAN DEFAULT false NOT NULL,
    is_premium BOOLEAN DEFAULT false NOT NULL,
    premium_expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.businesses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Verified and public businesses are viewable by all" ON public.businesses FOR SELECT USING (true);
CREATE POLICY "Owners can manage their listings" ON public.businesses FOR ALL USING (auth.uid() = owner_id);

-- 7. EVENTS Table
CREATE TABLE public.events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    location_name TEXT NOT NULL,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    ticket_price DECIMAL(10,2) DEFAULT 0.00 NOT NULL,
    capacity INTEGER,
    cover_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Events viewable by everyone" ON public.events FOR SELECT USING (true);
CREATE POLICY "Organizers can write events" ON public.events FOR ALL USING (auth.uid() = organizer_id);

-- 8. REPORTED CONTENT Table
CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reported_post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    reported_comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending' NOT NULL CONSTRAINT check_report_status CHECK (status IN ('pending', 'resolved', 'ignored')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Only admins/moderators can view and edit reports" ON public.reports FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role IN ('moderator', 'admin'))
);
CREATE POLICY "Users can create reports" ON public.reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- 9. PAYMENTS Table
CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'NPR'::character varying NOT NULL,
    payment_gateway VARCHAR(50) NOT NULL, -- 'razorpay' or 'dodo'
    gateway_payment_id TEXT UNIQUE NOT NULL,
    status VARCHAR(50) NOT NULL,
    entity_linked VARCHAR(50), -- 'business_listing', 'event_ticketing'
    linked_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins view all payments" ON public.payments FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin')
);
CREATE POLICY "Users view own payments" ON public.payments FOR SELECT USING (auth.uid() = user_id);