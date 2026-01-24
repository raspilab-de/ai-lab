#!/bin/sh
export LUA_PATH="/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua;;"
export LUA_CPATH="/usr/local/openresty/luajit/lib/lua/5.1/?.so;;"

set -e

apk add --no-cache gettext luarocks lua5.1-dev gcc make musl-dev >/dev/null

# install jwt_verification and deps
luarocks install lua-resty-openssl >/dev/null
luarocks install lua-resty-http >/dev/null
luarocks install lua-resty-jwt-verification >/dev/null

# ------------------------------------------------------------
# INIT MODE: Use HTTP-only template if certificates are missing
# ------------------------------------------------------------
NORMAL_TEMPLATE="/etc/nginx/templates/sites.conf.template"
INIT_TEMPLATE="/etc/nginx/templates/sites.init.conf.template"
TEMPLATE_TO_USE="$NORMAL_TEMPLATE"

# Expected certificate files (based on your current nginx template paths)
CERT_FILES="
/etc/letsencrypt/live/${HOST}.${DOMAIN}/fullchain.pem
/etc/letsencrypt/live/${HOST}.${DOMAIN}/privkey.pem
"

MISSING_CERTS=0
for f in $CERT_FILES; do
  if [ ! -s "$f" ]; then
    MISSING_CERTS=1
    break
  fi
done

if [ "$MISSING_CERTS" -eq 1 ]; then
  if [ -f "$INIT_TEMPLATE" ]; then
    echo "[render] Certificates missing -> using INIT template: $INIT_TEMPLATE"
    TEMPLATE_TO_USE="$INIT_TEMPLATE"
  else
    echo "[render] Certificates missing and INIT template not found!"
    echo "[render] Expected INIT template at: $INIT_TEMPLATE"
    echo "[render] Falling back to NORMAL template (nginx may fail)."
  fi
else
  echo "[render] Certificates found -> using NORMAL template: $NORMAL_TEMPLATE"
fi

# Render nginx config from selected template
envsubst < "$TEMPLATE_TO_USE" > /etc/nginx/conf.d/sites.conf.tmp

# Replace placeholders for nginx runtime variables ($host, $request_uri)
awk '
{ gsub(/__NGX_HOST__/, "$host"); gsub(/__NGX_URI__/, "$request_uri"); print }
' /etc/nginx/conf.d/sites.conf.tmp > /etc/nginx/conf.d/sites.conf

rm -f /etc/nginx/conf.d/sites.conf.tmp

# Validate config before starting
nginx -t

exec nginx -g "daemon off;"
