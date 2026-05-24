-- =====================================================================
-- Merch Phase B: orders + checkout
--
-- Applied via Supabase MCP on 2026-05-24. Saved here for reproducibility
-- and so it lives alongside the rest of the schema in version control.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Shared trigger function for touching updated_at
-- ---------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Sequence backing the human-readable order number (HT-NNNNNN)
-- ---------------------------------------------------------------------
create sequence if not exists public.site_orders_seq start 1000;

-- ---------------------------------------------------------------------
-- 1. site_orders — one row per submitted order
-- ---------------------------------------------------------------------
create table if not exists public.site_orders (
  id uuid primary key default gen_random_uuid(),

  order_number text unique not null,

  status text not null default 'pending'
    check (status in ('pending', 'paid', 'shipped', 'cancelled', 'refunded')),

  customer_name  text not null,
  customer_email text not null,
  customer_phone text not null,

  shipping_address_line1 text not null,
  shipping_address_line2 text,
  shipping_city          text not null,
  shipping_province      text not null,
  shipping_postal_code   text not null,

  notes text,

  subtotal_cents int not null check (subtotal_cents >= 0),
  shipping_cents int not null check (shipping_cents >= 0),
  total_cents    int not null check (total_cents    >= 0),
  currency       text not null default 'ZAR',

  -- Filled by Phase C (PayFast IPN). Null for now.
  payment_provider     text,
  payment_provider_ref text,
  payment_completed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.site_orders is
  'Hilltrek merch orders. Guest checkout — no auth required. Anon can INSERT only via the place_order() SECURITY DEFINER RPC; nobody can read except admins.';

create index if not exists site_orders_email_idx      on public.site_orders (customer_email);
create index if not exists site_orders_status_idx     on public.site_orders (status);
create index if not exists site_orders_created_at_idx on public.site_orders (created_at desc);

drop trigger if exists site_orders_touch_updated_at on public.site_orders;
create trigger site_orders_touch_updated_at
  before update on public.site_orders
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- 2. site_order_items — line items, snapshotted at order time
-- ---------------------------------------------------------------------
create table if not exists public.site_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.site_orders(id) on delete cascade,

  -- Snapshotted so if the product is later edited/deleted, the order
  -- record stays accurate.
  product_slug  text not null,
  product_name  text not null,
  product_image text,
  variants      jsonb not null default '{}'::jsonb,

  unit_price_cents int not null check (unit_price_cents >= 0),
  quantity         int not null check (quantity > 0),
  line_total_cents int not null check (line_total_cents >= 0),

  created_at timestamptz not null default now()
);

create index if not exists site_order_items_order_id_idx on public.site_order_items (order_id);

-- ---------------------------------------------------------------------
-- 3. site_settings — KVP settings table
-- ---------------------------------------------------------------------
create table if not exists public.site_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

drop trigger if exists site_settings_touch_updated_at on public.site_settings;
create trigger site_settings_touch_updated_at
  before update on public.site_settings
  for each row execute function public.touch_updated_at();

insert into public.site_settings (key, value) values
  ('shipping_flat_rate_cents', '15000'::jsonb),
  ('order_email_recipient',    '"info@hilltrek.co.za"'::jsonb)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 4. RLS
-- ---------------------------------------------------------------------
alter table public.site_orders      enable row level security;
alter table public.site_order_items enable row level security;
alter table public.site_settings    enable row level security;

drop policy if exists "Admins read orders"      on public.site_orders;
drop policy if exists "Admins write orders"     on public.site_orders;
create policy "Admins read orders"  on public.site_orders for select to authenticated using (public.is_admin());
create policy "Admins write orders" on public.site_orders for all    to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Admins read order items"  on public.site_order_items;
drop policy if exists "Admins write order items" on public.site_order_items;
create policy "Admins read order items"  on public.site_order_items for select to authenticated using (public.is_admin());
create policy "Admins write order items" on public.site_order_items for all    to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "Public reads settings" on public.site_settings;
drop policy if exists "Admins write settings" on public.site_settings;
create policy "Public reads settings" on public.site_settings for select to anon, authenticated using (true);
create policy "Admins write settings" on public.site_settings for all    to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- 5. place_order() — SECURITY DEFINER RPC for anon checkout
-- ---------------------------------------------------------------------
create or replace function public.place_order(
  p_items    jsonb,    -- [{slug, qty, variants}]
  p_customer jsonb     -- {name, email, phone, address1, address2, city, province, postal, notes}
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order_id    uuid;
  v_order_num   text;
  v_subtotal    int := 0;
  v_shipping    int := 15000;
  v_total       int;
  v_item        jsonb;
  v_product     public.site_products;
  v_qty         int;
  v_line_total  int;
  v_seq         bigint;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'No items in cart';
  end if;
  if p_customer is null then
    raise exception 'No customer info';
  end if;

  if coalesce(p_customer->>'name',     '') = '' then raise exception 'Name required';         end if;
  if coalesce(p_customer->>'email',    '') = '' then raise exception 'Email required';        end if;
  if coalesce(p_customer->>'phone',    '') = '' then raise exception 'Phone required';        end if;
  if coalesce(p_customer->>'address1', '') = '' then raise exception 'Address required';      end if;
  if coalesce(p_customer->>'city',     '') = '' then raise exception 'City required';         end if;
  if coalesce(p_customer->>'province', '') = '' then raise exception 'Province required';     end if;
  if coalesce(p_customer->>'postal',   '') = '' then raise exception 'Postal code required';  end if;

  select coalesce((value::text)::int, 15000) into v_shipping
    from public.site_settings where key = 'shipping_flat_rate_cents';

  v_seq := nextval('public.site_orders_seq');
  v_order_num := 'HT-' || lpad(v_seq::text, 6, '0');

  insert into public.site_orders (
    order_number, status,
    customer_name, customer_email, customer_phone,
    shipping_address_line1, shipping_address_line2,
    shipping_city, shipping_province, shipping_postal_code,
    notes,
    subtotal_cents, shipping_cents, total_cents
  ) values (
    v_order_num, 'pending',
    p_customer->>'name', p_customer->>'email', p_customer->>'phone',
    p_customer->>'address1', nullif(p_customer->>'address2', ''),
    p_customer->>'city', p_customer->>'province', p_customer->>'postal',
    nullif(p_customer->>'notes', ''),
    0, v_shipping, v_shipping
  ) returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    if (v_item->>'slug') is null then raise exception 'Missing product slug in cart item'; end if;
    v_qty := coalesce((v_item->>'qty')::int, 0);
    if v_qty <= 0 then raise exception 'Invalid quantity for %', v_item->>'slug'; end if;

    select * into v_product
      from public.site_products
      where slug = v_item->>'slug' and is_active = true
      for share;

    if not found then
      raise exception 'Product not available: %', v_item->>'slug';
    end if;

    if v_product.track_inventory and v_product.stock_quantity is not null and v_product.stock_quantity < v_qty then
      raise exception 'Not enough stock for %: % requested, % available',
        v_product.name, v_qty, v_product.stock_quantity;
    end if;

    v_line_total := v_product.price_cents * v_qty;
    v_subtotal   := v_subtotal + v_line_total;

    insert into public.site_order_items (
      order_id, product_slug, product_name, product_image,
      variants, unit_price_cents, quantity, line_total_cents
    ) values (
      v_order_id, v_product.slug, v_product.name, v_product.main_image_url,
      coalesce(v_item->'variants', '{}'::jsonb),
      v_product.price_cents, v_qty, v_line_total
    );

    if v_product.track_inventory and v_product.stock_quantity is not null then
      update public.site_products
        set stock_quantity = stock_quantity - v_qty,
            updated_at = now()
        where id = v_product.id;
    end if;
  end loop;

  v_total := v_subtotal + v_shipping;

  update public.site_orders
    set subtotal_cents = v_subtotal,
        total_cents    = v_total,
        updated_at     = now()
    where id = v_order_id;

  return jsonb_build_object(
    'id',             v_order_id,
    'order_number',   v_order_num,
    'subtotal_cents', v_subtotal,
    'shipping_cents', v_shipping,
    'total_cents',    v_total,
    'currency',       'ZAR'
  );
end;
$$;

grant execute on function public.place_order(jsonb, jsonb) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. get_order_for_confirmation() — limited shopper view by id
-- ---------------------------------------------------------------------
create or replace function public.get_order_for_confirmation(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.site_orders;
  v_items jsonb;
begin
  select * into v_order from public.site_orders where id = p_order_id;
  if not found then return null; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'product_name',     product_name,
    'product_image',    product_image,
    'variants',         variants,
    'quantity',         quantity,
    'unit_price_cents', unit_price_cents,
    'line_total_cents', line_total_cents
  ) order by created_at), '[]'::jsonb) into v_items
    from public.site_order_items where order_id = p_order_id;

  return jsonb_build_object(
    'order_number',   v_order.order_number,
    'status',         v_order.status,
    'customer_name',  v_order.customer_name,
    'customer_email', v_order.customer_email,
    'subtotal_cents', v_order.subtotal_cents,
    'shipping_cents', v_order.shipping_cents,
    'total_cents',    v_order.total_cents,
    'currency',       v_order.currency,
    'created_at',     v_order.created_at,
    'items',          v_items
  );
end;
$$;

grant execute on function public.get_order_for_confirmation(uuid) to anon, authenticated;
