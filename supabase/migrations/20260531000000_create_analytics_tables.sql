-- Analytics event log: raw events for funnel queries, trust scoring, cohort analysis
create table if not exists analytics_events (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  session_id  text        not null,
  event_name  text        not null,
  properties  jsonb       not null default '{}',
  farm_id     uuid        references farms(id) on delete set null,
  pond_id     uuid        references ponds(id) on delete set null,
  app_version text,
  platform    text,
  created_at  timestamptz not null default now()
);

create index if not exists idx_ae_user_event_time on analytics_events(user_id, event_name, created_at);
create index if not exists idx_ae_event_time       on analytics_events(event_name, created_at);
create index if not exists idx_ae_pond_event       on analytics_events(pond_id, event_name);
create index if not exists idx_ae_session          on analytics_events(session_id);
create index if not exists idx_ae_properties       on analytics_events using gin(properties);

alter table analytics_events enable row level security;

create policy "analytics_events_insert_own"
  on analytics_events for insert
  with check (user_id = auth.uid());

create policy "analytics_events_select_own"
  on analytics_events for select
  using (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- Computed user cohort properties (updated by client on key lifecycle events)
create table if not exists user_analytics (
  user_id                  uuid        primary key references auth.users(id) on delete cascade,
  first_open_at            timestamptz,
  account_created_at       timestamptz,
  first_farm_at            timestamptz,
  first_pond_at            timestamptz,
  first_feed_log_at        timestamptz,
  first_tray_log_at        timestamptz,
  last_active_at           timestamptz,
  d1_retained              boolean     not null default false,
  d7_retained              boolean     not null default false,
  d30_retained             boolean     not null default false,
  total_feed_logs          int         not null default 0,
  total_tray_logs          int         not null default 0,
  recommendations_shown    int         not null default 0,
  recommendations_accepted int         not null default 0,
  recommendations_overridden int       not null default 0,
  subscription_tier        text        not null default 'free',
  farm_count               int         not null default 0,
  pond_count               int         not null default 0,
  updated_at               timestamptz not null default now()
);

alter table user_analytics enable row level security;

create policy "user_analytics_insert_own"
  on user_analytics for insert
  with check (user_id = auth.uid());

create policy "user_analytics_update_own"
  on user_analytics for update
  using (user_id = auth.uid());

create policy "user_analytics_select_own"
  on user_analytics for select
  using (user_id = auth.uid());
