-- Register coupon usage from checkout clients without exposing direct table writes.
-- This function is SECURITY DEFINER so anon/authenticated users can record usage
-- after an order is created while coupon_usage remains protected by RLS.

create or replace function public.register_coupon_usage(
  p_coupon_id uuid,
  p_order_id uuid,
  p_customer_phone text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_coupon_id is null or p_order_id is null then
    return;
  end if;

  if p_customer_phone is null or btrim(p_customer_phone) = '' then
    return;
  end if;

  insert into public.coupon_usage (
    coupon_id,
    order_id,
    customer_phone
  )
  values (
    p_coupon_id,
    p_order_id,
    btrim(p_customer_phone)
  );

  perform public.increment_coupon_usage(p_coupon_id);
end;
$$;

grant execute on function public.register_coupon_usage(uuid, uuid, text) to anon;
grant execute on function public.register_coupon_usage(uuid, uuid, text) to authenticated;
