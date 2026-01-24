#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=".env"
SCRIPT_VERSION="2.0.0"

# ---- Farben für Ausgabe ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---- Helper functions ----
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✔${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✖${NC} $1"; }

show_help() {
  cat << EOF
┌─────────────────────────────────────────────────────────────┐
│  create-env.sh - AI-Lab .env Generator v${SCRIPT_VERSION}        │
└─────────────────────────────────────────────────────────────┘

VERWENDUNG:
  ./create-env.sh [OPTIONEN]

OPTIONEN:
  --defaults    Non-Interactive Mode: Verwendet alle Standardwerte
                (Passwörter werden automatisch generiert)
  --help        Zeigt diese Hilfe an

BEISPIELE:
  ./create-env.sh              # Interaktiver Modus
  ./create-env.sh --defaults   # Automatisch mit Standardwerten

EOF
  exit 0
}

prompt_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default_val="$3"
  local input

  read -r -p "${prompt_text} [${default_val}]: " input
  if [[ -z "${input}" ]]; then
    printf -v "$var_name" "%s" "$default_val"
  else
    printf -v "$var_name" "%s" "$input"
  fi
}

prompt_required() {
  local var_name="$1"
  local prompt_text="$2"
  local input

  while true; do
    read -r -p "${prompt_text}: " input
    if [[ -n "${input}" ]]; then
      printf -v "$var_name" "%s" "$input"
      return 0
    fi
    print_error "Eingabe darf nicht leer sein."
  done
}

prompt_secret_default() {
  local var_name="$1"
  local prompt_text="$2"
  local default_val="$3"
  local input

  read -r -s -p "${prompt_text} [${default_val}]: " input
  echo
  if [[ -z "${input}" ]]; then
    printf -v "$var_name" "%s" "$default_val"
  else
    printf -v "$var_name" "%s" "$input"
  fi
}

rand_pw() {
  # 24 chars random (kryptografisch sicher)
  # Hinweis: Das - muss am Ende stehen, damit es nicht als Bereichsoperator interpretiert wird
  # Wir lesen mehr Bytes (256), um sicherzustellen, dass genug passende Zeichen vorhanden sind
  head -c 256 /dev/urandom | tr -dc 'A-Za-z0-9!@^_+-' | head -c 24
}

validate_email() {
  local email="$1"
  if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    return 0
  else
    return 1
  fi
}

prompt_email() {
  local var_name="$1"
  local prompt_text="$2"
  local default_val="$3"
  local input

  while true; do
    read -r -p "${prompt_text} [${default_val}]: " input
    if [[ -z "${input}" ]]; then
      input="$default_val"
    fi

    if validate_email "$input"; then
      printf -v "$var_name" "%s" "$input"
      return 0
    else
      print_error "Ungültiges E-Mail-Format. Bitte erneut eingeben."
    fi
  done
}

confirm() {
  local prompt="${1:-Weiter?}"
  local yn
  while true; do
    read -r -p "${prompt} (y/n): " yn
    case "$yn" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Bitte y oder n eingeben." ;;
    esac
  done
}

create_backup() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local backup_file="${file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$file" "$backup_file"
    print_success "Backup erstellt: ${backup_file}"
  fi
}

# ---- Argument Parsing ----
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --defaults)
      NON_INTERACTIVE=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      print_error "Unbekannte Option: $1"
      echo "Verwende --help für Hilfe."
      exit 1
      ;;
  esac
done

# ---- Defaults ----
# Statische Defaults
DEFAULT_DOMAIN_NAME="raspilab.de"
DEFAULT_SUBDOMAIN="ai-lab"
DEFAULT_HOST="ai-lab"
DEFAULT_UPSTREAM_OPENWEBUI="openwebui:8080"
DEFAULT_UPSTREAM_N8N="n8n:5678"
DEFAULT_UPSTREAM_S3="minio:9000"
DEFAULT_GENERIC_TIMEZONE="Europe/Berlin"
DEFAULT_SSL_EMAIL="admin@ai-lab.raspilab.de"
DEFAULT_SHARED_FOLDER="shared"
DEFAULT_IMAGE_FOLDER="images"
DEFAULT_MINIO_USER="admin"
DEFAULT_POSTGRES_USER="dbadmin"
DEFAULT_POSTGRES_DB="postgres"

# Dynamische Defaults (zufällige Passwörter)
DEFAULT_MINIO_PASSWORD="$(rand_pw)"
DEFAULT_POSTGRES_PASSWORD="$(rand_pw)"

echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  .env Generator für deinen AI-Lab Stack v${SCRIPT_VERSION}              │"
echo "│  Datei wird erstellt: ${ENV_FILE}                                  │"
echo "└─────────────────────────────────────────────────────────────┘"
echo

if [[ "$NON_INTERACTIVE" == true ]]; then
  print_info "Non-Interactive Mode aktiviert (--defaults)"
  echo
fi

# ---- Bestehende .env prüfen ----
if [[ -f "${ENV_FILE}" ]]; then
  print_warning "Es existiert bereits eine ${ENV_FILE}."
  
  if [[ "$NON_INTERACTIVE" == true ]]; then
    create_backup "${ENV_FILE}"
  else
    if confirm "Überschreiben? (Backup wird automatisch erstellt)"; then
      create_backup "${ENV_FILE}"
    else
      echo "Abgebrochen."
      exit 0
    fi
  fi
  echo
fi

# ---- Werte sammeln ----
if [[ "$NON_INTERACTIVE" == true ]]; then
  # Non-Interactive: Alle Defaults verwenden
  DOMAIN_NAME="$DEFAULT_DOMAIN_NAME"
  SUBDOMAIN="$DEFAULT_SUBDOMAIN"
  HOST="$DEFAULT_HOST"
  UPSTREAM_OPENWEBUI="$DEFAULT_UPSTREAM_OPENWEBUI"
  UPSTREAM_N8N="$DEFAULT_UPSTREAM_N8N"
  UPSTREAM_S3="$DEFAULT_UPSTREAM_S3"
  GENERIC_TIMEZONE="$DEFAULT_GENERIC_TIMEZONE"
  SSL_EMAIL="$DEFAULT_SSL_EMAIL"
  SHARED_FOLDER="$DEFAULT_SHARED_FOLDER"
  IMAGE_FOLDER="$DEFAULT_IMAGE_FOLDER"
  MINIO_ROOT_USER="$DEFAULT_MINIO_USER"
  MINIO_ROOT_PASSWORD="$DEFAULT_MINIO_PASSWORD"
  POSTGRES_USER="$DEFAULT_POSTGRES_USER"
  POSTGRES_PASSWORD="$DEFAULT_POSTGRES_PASSWORD"
  POSTGRES_DB="$DEFAULT_POSTGRES_DB"
  
  print_success "Alle Standardwerte übernommen"
  print_info "Passwörter wurden automatisch generiert"
  echo
else
  # Interactive Mode
  echo "=== Domain & Reverse Proxy ==="
  prompt_default DOMAIN_NAME "Top-Level Domain (z.B. raspilab.de)" "${DEFAULT_DOMAIN_NAME}"
  prompt_default SUBDOMAIN   "Subdomain (z.B. ai-lab)" "${DEFAULT_SUBDOMAIN}"
  prompt_default HOST        "Hostname/Stack-Name (meist identisch mit SUBDOMAIN)" "${DEFAULT_HOST}"
  echo

  echo "=== Upstreams im Docker-Netzwerk (normalerweise unverändert) ==="
  prompt_default UPSTREAM_OPENWEBUI "OpenWebUI Upstream" "${DEFAULT_UPSTREAM_OPENWEBUI}"
  prompt_default UPSTREAM_N8N       "n8n Upstream" "${DEFAULT_UPSTREAM_N8N}"
  prompt_default UPSTREAM_S3        "MinIO S3 Upstream" "${DEFAULT_UPSTREAM_S3}"
  echo

  echo "=== Zeitzone & SSL ==="
  prompt_default GENERIC_TIMEZONE "Zeitzone (z.B. Europe/Berlin)" "${DEFAULT_GENERIC_TIMEZONE}"
  
  # E-Mail mit Validierung
  while true; do
    prompt_default SSL_EMAIL "E-Mail für Let's Encrypt" "${DEFAULT_SSL_EMAIL}"
    if validate_email "$SSL_EMAIL"; then
      break
    else
      print_error "Ungültiges E-Mail-Format. Bitte erneut eingeben."
    fi
  done
  echo

  echo "=== Ordner (relativ zum Compose-Verzeichnis) ==="
  prompt_default SHARED_FOLDER "Shared Folder (z.B. shared)" "${DEFAULT_SHARED_FOLDER}"
  prompt_default IMAGE_FOLDER  "Image Folder (z.B. images)" "${DEFAULT_IMAGE_FOLDER}"
  echo

  echo "=== MinIO Zugangsdaten ==="
  prompt_default MINIO_ROOT_USER "MinIO Root User" "${DEFAULT_MINIO_USER}"

  echo "MinIO Root Passwort:"
  echo "  - ENTER generiert ein sicheres Zufallspasswort"
  echo "  - oder tippe ein eigenes Passwort ein"
  read -r -s -p "MinIO Root Passwort [<AUTO-GENERATED>]: " minio_pw_input
  echo
  if [[ -z "${minio_pw_input}" ]]; then
    MINIO_ROOT_PASSWORD="$DEFAULT_MINIO_PASSWORD"
    print_success "Sicheres Passwort generiert"
  else
    MINIO_ROOT_PASSWORD="${minio_pw_input}"
  fi
  echo

  echo "=== Postgres Zugangsdaten ==="
  prompt_default POSTGRES_USER "Postgres User" "${DEFAULT_POSTGRES_USER}"

  echo "Postgres Passwort:"
  echo "  - ENTER generiert ein sicheres Zufallspasswort"
  echo "  - oder tippe ein eigenes Passwort ein"
  read -r -s -p "Postgres Passwort [<AUTO-GENERATED>]: " pg_pw_input
  echo
  if [[ -z "${pg_pw_input}" ]]; then
    POSTGRES_PASSWORD="$DEFAULT_POSTGRES_PASSWORD"
    print_success "Sicheres Passwort generiert"
  else
    POSTGRES_PASSWORD="${pg_pw_input}"
  fi

  prompt_default POSTGRES_DB "Postgres DB Name" "${DEFAULT_POSTGRES_DB}"
  echo
fi

# ---- Zusammenfassung ----
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  Zusammenfassung                                            │"
echo "└─────────────────────────────────────────────────────────────┘"
echo "DOMAIN_NAME=${DOMAIN_NAME}"
echo "SUBDOMAIN=${SUBDOMAIN}"
echo "HOST=${HOST}"
echo "UPSTREAM_OPENWEBUI=${UPSTREAM_OPENWEBUI}"
echo "UPSTREAM_N8N=${UPSTREAM_N8N}"
echo "UPSTREAM_S3=${UPSTREAM_S3}"
echo "GENERIC_TIMEZONE=${GENERIC_TIMEZONE}"
echo "SSL_EMAIL=${SSL_EMAIL}"
echo "SHARED_FOLDER=${SHARED_FOLDER}"
echo "IMAGE_FOLDER=${IMAGE_FOLDER}"
echo "MINIO_ROOT_USER=${MINIO_ROOT_USER}"
echo "MINIO_ROOT_PASSWORD=********"
echo "POSTGRES_USER=${POSTGRES_USER}"
echo "POSTGRES_PASSWORD=********"
echo "POSTGRES_DB=${POSTGRES_DB}"
echo

# ---- Bestätigung (nur im Interactive Mode) ----
if [[ "$NON_INTERACTIVE" == false ]]; then
  if ! confirm "Diese Werte in .env schreiben?"; then
    echo "Abgebrochen."
    exit 0
  fi
fi

# ---- .env schreiben ----
cat > "${ENV_FILE}" <<EOF
# ============================================================
# AI-Lab Environment Configuration
# Generated by create-env.sh v${SCRIPT_VERSION}
# Date: $(date +%Y-%m-%d\ %H:%M:%S)
# ============================================================

# The top level domain to serve from
DOMAIN_NAME=${DOMAIN_NAME}

# The subdomain to serve from
SUBDOMAIN=${SUBDOMAIN}
HOST=${HOST}

# Docker network upstreams
UPSTREAM_OPENWEBUI=${UPSTREAM_OPENWEBUI}
UPSTREAM_N8N=${UPSTREAM_N8N}
UPSTREAM_S3=${UPSTREAM_S3}

# Optional timezone to set which gets used by Cron and other scheduling nodes
GENERIC_TIMEZONE=${GENERIC_TIMEZONE}

# The email address to use for the TLS/SSL certificate creation
SSL_EMAIL=${SSL_EMAIL}

# Folder for File-Exchange between n8n and docling
SHARED_FOLDER=${SHARED_FOLDER}
IMAGE_FOLDER=${IMAGE_FOLDER}

# Credentials for MinIO
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}

# Credentials for Postgres
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
EOF

chmod 600 "${ENV_FILE}"

echo
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  ✔ Fertig!                                                  │"
echo "└─────────────────────────────────────────────────────────────┘"
print_success "${ENV_FILE} wurde erstellt (Berechtigungen: 600)"

if [[ "$NON_INTERACTIVE" == true ]]; then
  echo
  print_warning "WICHTIG: Notiere dir die generierten Passwörter!"
  echo "  MinIO:    ${MINIO_ROOT_PASSWORD}"
  echo "  Postgres: ${POSTGRES_PASSWORD}"
fi

echo
print_info "Nächste Schritte:"
echo "  1. docker compose pull"
echo "  2. docker compose up -d"

