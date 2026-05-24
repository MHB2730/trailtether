-- =====================================================================
-- Merch Phase C: PayFast integration — audit log for ITN callbacks
--
-- Applied via Supabase MCP on 2026-05-24. Saved here for reproducibility
-- alongside the rest of the schema.
-- =====================================================================

create table if not exists public.site_payment_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.site_orders(id) on delete set null,
  provider text not null,
  payload jsonb not null,
  signature_valid boolean,
  validate_ok     boolean,
  ip_address text,
  received_at timestamptz not null default now()
);

comment on table public.site_payment_events is
  'Audit log of every payment-gateway callback received. Insert-only via service-role Edge Function; admin-readable.';

create index if not exists site_payment_events_order_id_idx
  on public.site_payment_events (order_id);
create index if not exists site_payment_events_received_at_idx
  on public.site_payment_events (received_at desc);

alter table public.site_payment_events enable row level security;

drop policy if exists "Admins read payment events"  on public.site_payment_events;
drop policy if exists "Admins write payment events" on public.site_payment_events;

create policy "Admins read payment events"
  on public.site_payment_events for select
  to authenticated using (public.is_admin());

create policy "Admins write payment events"
  on public.site_payment_events for all
  to authenticated using (public.is_admin())
  with check (public.is_admin());
