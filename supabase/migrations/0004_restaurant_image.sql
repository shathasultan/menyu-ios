-- منيو — صورة غلاف/شعار المطعم
alter table public.restaurants
  add column if not exists image_url text;
