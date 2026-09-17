#!/usr/bin/env bash
# يشغّل هجرات منيو كلها على PostgreSQL محلي مؤقت ثم ينفّذ فحوص السلوك.
# لا يلمس قاعدة Supabase إطلاقًا — قاعدة جديدة تُنشأ وتُهدم في كل مرة.
#
#   brew install postgresql@16   (على الماك)
#   bash supabase/tests/run.sh
set -euo pipefail

BIN="${PG_BIN:-$(dirname "$(command -v initdb)")}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap '"$BIN/pg_ctl" -D "$TMP/data" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$TMP"' EXIT

"$BIN/initdb" -D "$TMP/data" -A trust -E UTF8 --locale=C >/dev/null
"$BIN/pg_ctl" -D "$TMP/data" -o "-k $TMP -h ''" -l "$TMP/log" start >/dev/null
"$BIN/createdb" -h "$TMP" menyu_test

psql() { "$BIN/psql" -h "$TMP" -d menyu_test "$@"; }

echo "— تهيئة محاكاة Supabase (auth وstorage والأدوار)"
psql -qv ON_ERROR_STOP=1 -f "$DIR/supabase/tests/00_supabase_stub.sql"

echo "— تشغيل الهجرات بالترتيب"
for f in "$DIR"/supabase/migrations/0*.sql; do
  printf '   %-46s ' "$(basename "$f")"
  if psql -qv ON_ERROR_STOP=1 -f "$f" >"$TMP/out" 2>&1; then echo "OK"; else echo "FAIL"; cat "$TMP/out"; exit 1; fi
done

echo "— بذر المستخدمين"
psql -qc "insert into auth.users (id,email) values
 ('11111111-1111-1111-1111-111111111111','ownerA@test.sa'),
 ('22222222-2222-2222-2222-222222222222','ownerB@test.sa'),
 ('33333333-3333-3333-3333-333333333333','demo.admin@menyu.sa')
 on conflict do nothing"

echo "— فحوص السلوك"
psql -f "$DIR/supabase/tests/01_behaviour.sql" 2>&1 | tail -40

FAILED=$(psql -tAc "select count(*) from t_results where expected <> got")
echo
if [ "$FAILED" = "0" ]; then echo "كل الفحوص ناجحة."; else echo "فحوص فاشلة: $FAILED"; exit 1; fi
