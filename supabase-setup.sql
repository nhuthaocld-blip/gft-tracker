-- GFT Tracker: tạo chỗ lưu dữ liệu trên Supabase
-- Cách dùng: Supabase > SQL Editor > New query > dán toàn bộ file này > bấm Run.

-- Mỗi "mã cá nhân" là 1 dòng. Không lưu mã gốc, chỉ lưu mã đã băm (SHA-256).
create table if not exists public.gft_store (
  code_hash  text primary key,
  data       jsonb not null,
  updated_at timestamptz not null default now()
);

-- Khoá bảng: không ai đọc/ghi trực tiếp được (kể cả liệt kê toàn bộ),
-- chỉ đi qua 3 hàm bên dưới và phải biết đúng mã.
alter table public.gft_store enable row level security;
revoke all on public.gft_store from anon, authenticated;

-- Đọc dữ liệu theo mã
create or replace function public.gft_get(p_hash text)
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object('data', data, 'updated_at', updated_at)
  from gft_store where code_hash = p_hash;
$$;

-- Tạo tài khoản mới (trả về false nếu mã đã có người dùng)
create or replace function public.gft_create(p_hash text, p_data jsonb)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if length(p_hash) <> 64 then return false; end if;
  insert into gft_store(code_hash, data) values (p_hash, p_data);
  return true;
exception when unique_violation then
  return false;
end $$;

-- Lưu dữ liệu mới (trả về thời điểm lưu, hoặc null nếu mã không tồn tại)
create or replace function public.gft_put(p_hash text, p_data jsonb)
returns timestamptz language sql security definer set search_path = public as $$
  update gft_store set data = p_data, updated_at = now()
  where code_hash = p_hash
  returning updated_at;
$$;

revoke all on function public.gft_get(text), public.gft_create(text, jsonb), public.gft_put(text, jsonb) from public;
grant execute on function public.gft_get(text), public.gft_create(text, jsonb), public.gft_put(text, jsonb) to anon;
