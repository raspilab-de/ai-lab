# AI-Lab Installation

Diese Anleitung beschreibt die vollständige Installation des AI-Lab Stacks auf einem Debian-basierten System.

---

## Inhaltsverzeichnis

1. [Voraussetzungen](#voraussetzungen)
2. [Docker Installation](#docker-installation)
3. [GPU-Support (Optional)](#gpu-support-optional)
4. [AI-Lab Installation](#ai-lab-installation)
5. [TLS-Zertifikate](#tls-zertifikate)
6. [Stack starten](#stack-starten)
7. [OpenWebUI Konfiguration](#openwebui-konfiguration)
8. [Ollama Modelle](#ollama-modelle)
9. [JWT-Zertifikate](#jwt-zertifikate)
10. [MinIO Konfiguration](#minio-konfiguration)
11. [Secured Mode aktivieren](#secured-mode-aktivieren)
12. [JWT-Token für Bild-URLs aktivieren (Experimentell)](#jwt-token-für-bild-urls-aktivieren-experimentell)
13. [n8n Workflow Konfiguration](#n8n-workflow-konfiguration)
14. [OpenWebUI mit n8n verbinden](#openwebui-mit-n8n-verbinden)
15. [URLs](#urls)

---

## Voraussetzungen

- Debian-basiertes System (Debian, Ubuntu, Raspberry Pi OS)
- Root-Zugriff oder sudo-Berechtigung
- Öffentlich erreichbare Domain mit DNS-Einträgen für:
  - `<host>.<domain>` (z.B. `ai-lab.raspilab.de`)
  - `n8n.<host>.<domain>` (z.B. `n8n.ai-lab.raspilab.de`)
  - `s3.<host>.<domain>` (z.B. `s3.ai-lab.raspilab.de`)

### Git installieren

```bash
sudo apt update
sudo apt install -y git
```

---

## Docker Installation

Installation gemäß [offizieller Docker-Dokumentation](https://docs.docker.com/engine/install/debian/):

```bash
# Docker GPG-Key hinzufügen
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Repository hinzufügen
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# Docker installieren
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

---

## GPU-Support (Optional)

Für Ollama mit NVIDIA GPU-Unterstützung muss das [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installiert werden:

```bash
# Abhängigkeiten installieren
sudo apt-get update
sudo apt-get install -y --no-install-recommends curl gnupg2

# NVIDIA Repository hinzufügen
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Toolkit installieren
sudo apt-get update
export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.18.1-1
sudo apt-get install -y \
    nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}

# Docker für NVIDIA konfigurieren
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### compose.yml für GPU anpassen

Wenn Ollama mit GPU-Support gestartet werden soll, muss die `compose.yml` angepasst werden.

Weitere Informationen: [Ollama Docker mit GPU](https://ollama.com/blog/ollama-is-now-available-as-an-official-docker-image)

**CPU Only:**
```yaml
ollama:
  image: ollama/ollama
  volumes:
    - ollama:/root/.ollama
```

**NVIDIA GPU:**
```yaml
ollama:
  image: ollama/ollama
  volumes:
    - ollama:/root/.ollama
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

---

## AI-Lab Installation

```bash
# Repository klonen
cd /opt
sudo git clone https://github.com/raspilab-de/ai-lab.git
cd ai-lab

# Umgebungsvariablen konfigurieren
sudo ./create-env.sh

# Images herunterladen
sudo docker compose pull
```

---

## MinIO Lizenz

Die Minio-Lizenz muss für den erfolgreichen Start im selben Verzeichnis wie die Compose-Datei liegen.
Eine Lizenz kann über folgenden Link bezogen werden: [https://www.min.io/download]

```bash
# Lizenz-Datei aus dem Benutzer-Verzeichnis kopieren.
cp ~/minio.license .

```

---

## TLS-Zertifikate

Beim ersten Start muss Nginx im Init-Modus gestartet werden, um die Let's Encrypt Zertifikate zu generieren:

```bash
# Nginx im Init-Modus starten
sudo docker compose up nginx -d

# Zertifikate anfordern (Domains anpassen!)
sudo docker compose run --rm --entrypoint certbot certbot certonly \
  --webroot -w /var/www/certbot \
  --agree-tos --no-eff-email \
  -m admin@<host>.<domain> \
  -d <host>.<domain> \
  -d n8n.<host>.<domain> \
  -d s3.<host>.<domain>

# Stack stoppen
sudo docker compose down
```

> **Hinweis:** Ersetze `<host>.<domain>` durch deine tatsächliche Domain (z.B. `ai-lab.raspilab.de`).

---

## Stack starten

```bash
sudo docker compose up -d
```

---

## OpenWebUI Konfiguration

1. Öffne `https://<host>.<domain>/` im Browser
2. Registriere einen Admin-Account
3. Wechsle in den **Admin-Bereich**
4. Navigiere zu **Einstellungen → Verbindungen**
5. Bearbeite den ersten Ollama-API-Eintrag:
   - **URL:** `http://ollama:11434`

---

## Ollama Modelle

Nach der Konfiguration der Ollama-Verbindung, wechsle zu **Modelle** und lade folgende Modelle herunter:

| Modell | Verwendung |
|--------|------------|
| `llama3.1:8b` | Haupt-LLM für Chat |
| `llama3.2:3b` | Leichtgewichtiges LLM |
| `llava:7b` | Bildanalyse (OCR-Workflow) |
| `nomic-embed-text:v1.5` | Embedding-Modell (RAG) |

---

## JWT-Zertifikate

Für die signierte URL-Generierung im OCR-Workflow werden RSA-Schlüssel benötigt:

```bash
# Verzeichnis erstellen
mkdir -p minio-jwt-keys
cd minio-jwt-keys

# Private Key generieren (für n8n)
openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:2048

# Public Key extrahieren (für Nginx)
openssl rsa -pubout -in private.pem -out public.pem
```

---

## MinIO Konfiguration

### MinIO Console öffnen

1. Öffne `http://<host>.<domain>:9001` im Browser
2. Melde dich mit den Credentials aus der `.env` an:
   - **User:** `MINIO_ROOT_USER`
   - **Password:** `MINIO_ROOT_PASSWORD`

### Bucket erstellen

1. Erstelle einen neuen Bucket: `n8n`
2. Typ: **Basic**

### Anonymous Access aktivieren

1. Wähle den Bucket `n8n`
2. Gehe zu **Access Rules**
3. Füge eine Regel hinzu:
   - **Prefix:** `/`
   - **Access:** `readonly`

### Access Key generieren

1. Navigiere zu **Access Keys**
2. Erstelle einen neuen Access Key
3. Notiere **Access Key** und **Secret Key**

---

## MinIO UI deaktivieren

Um den anonymen MinIO-Zugang mit JWT-Validierung abzusichern:

```bash
cd /opt/ai-lab
nano compose.yml

# Port 9001 in compose.yml deaktivieren (auskommentieren)
# ports:
# - "9001:9001"

# Services neu starten
sudo docker compose down nginx minio
sudo docker compose up nginx minio -d
```

---

## n8n Einrichtung

1. Öffne `https://n8n.<host>.<domain>` im Browser
2. erstelle einen Admin-Account

### Workflows importieren

1. Für den ersten Workflow auf "Start from Scrath" klicken
2. Import from URL `https://<host>.<domain>/workflows/GitLab_Ai_Agent.json`

1. Für alle weiteren Workflows auf "Create workflow" klicken
2. Import from URL `https://<host>.<domain>/workflows/OCR_Workflow.json`

### Credentials anlegen

Öffne den `OCR-Workflow` in n8n und erstelle folgende Credentials:

### 1. S3-Credentials in n8n eintragen

| Feld | Wert |
|------|------|
| **S3 Endpoint** | `http://minio:9000` |
| **Region** | `us-east-1` |
| **Access Key ID** | <Wert aus MinIO> |
| **Secret Access Key** | <Wert aus MinIO> |
| **Force Path Style** | ✅ Aktivieren |

### 2. JWT-Zertifikate

| Feld | Wert |
|------|------|
| **Key Type** | `PEM Key` |
| **Private Key** | Inhalt der Datei `minio-jwt-keys/private.pem` |
| **Public Key** | Inhalt der Datei `minio-jwt-keys/public.pem` |
| **Algorithm** | `RS256` |

Der Workflow kann anschliessend veröffentlicht werden.
Öffne den `GitLab Ai Agent` in n8n und erstelle folgende Credentials:

#### 1. Webhook Authentication

| Feld | Wert |
|------|------|
| **Name** | `Authorization` |
| **Value** | `Bearer <token>` |

> **Wichtig:** Notiere den Token (z.B. `1234`) – dieser wird später für OpenWebUI benötigt.

#### 2. Ollama

| Feld | Wert |
|------|------|
| **Base URL** | `http://ollama:11434` |
| **API Key** | (leer lassen) |

#### 3. PostgreSQL

| Feld | Wert |
|------|------|
| **Host** | `postgres` |
| **Database** | `postgres` |
| **User** | (aus `.env`) |
| **Password** | (aus `.env`) |

#### 4. SerpAPI

1. Registriere dich auf [serpapi.com](https://serpapi.com/)
2. Trage den API-Key ein

#### 5. GitLab

1. Generiere einen **Personal Access Token** auf deinem GitLab-Server
2. Trage die Werte ein:
   - **URL:** URL deines GitLab-Servers
   - **Access Token:** Personal Access Token
3. Aktiviere die Credentials für **alle GitLab-Tool-Knoten**

#### 6. Azure OpenAI (Optional)

| Feld | Wert |
|------|------|
| **API Key** | (aus AI Foundry) |
| **Resource Name** | (Name der Ressource in AI Foundry) |
| **Endpoint** | (aus AI Foundry) |

### Workflows verbinden

1. Öffne den **GitLab AI Agent** Workflow
2. Den Node `Call OCR-Workflow` öffnen.
3. Aus der liste den Workflow erneut auswählen.

### Datenbank initialisieren

1. Öffne den **GitLab AI Agent** Workflow
2. Führe den Knoten **Create Document Metadata Table** aus
3. Führe den Knoten **Create Vector-Extension** aus

## RAG mit Dokumenten füllen

1. Öffne den **GitLab AI Agent** Workflow
2. Workflow veröffentlichen
3. Öffne den Node `Submit File-Form`
4. Kopiere die **Production URL**

> **Hinweis:** Die URL hat zwei Formate:
> - **Intern (im Stack):** `http://n8n:5678/form/<id>`
> - **Extern (Browser):** `https://n8n.<host>.<domain>/form/<id>`

5. Öffne die **Form-URL** des GitLab AI Agent:
   `https://n8n.<host>.<domain>/form/<form-id>`
6. Gib die Repository-URL an
7. Optional: Spezifische Datei angeben, sonst wird das gesamte Repository indexiert

---

## Open-WebUI mit n8n verbinden

### Funktion in Open-WebUI importieren

1. Öffne OpenWebUI: `https://<host>.<domain>/`
2. Wechsle in den **Admin-Bereich**
3. Navigiere zu **Funktionen**
4. Klicke auf **Neue Funktion**
5. Wähle **Von Link importieren**
6. Importiere die Funktion aus:
   `https://<host>.<domain>/functions/function-n8n_pipe.json`
7. **Speichern und bestätigen**

### Webhook-URL notieren

1. Öffne in n8n den **GitLab AI Agent** Workflow
2. Öffne den **Webhook-Knoten**
3. Kopiere die **Production URL**

> **Hinweis:** Die URL hat zwei Formate:
> - **Intern (im Stack):** `http://n8n:5678/webhook/<id>`
> - **Extern (Browser):** `https://n8n.<host>.<domain>/webhook/<id>`

### Funktion konfigurieren

1. Klicke auf das **Zahnrad** neben der Funktion
2. Konfiguriere die Werte:

| Feld | Wert |
|------|------|
| **N8N URL** | `http://n8n:5678/webhook/<webhook-id>` |
| **N8N Bearer Token** | Token aus den Webhook-Credentials (z.B. `1234`) |

3. **Speichern**
4. **Funktion aktivieren** (Schieberegler nach rechts)

### Verwendung

Nach der Aktivierung steht in OpenWebUI ein neues Modell **n8n Pipe Function** zur Verfügung. Alle Eingaben werden an den n8n-Workflow weitergeleitet und die Antworten in OpenWebUI angezeigt.

---

## URLs

Nach erfolgreicher Installation sind folgende Endpunkte verfügbar:

| Dienst | URL |
|--------|-----|
| **OpenWebUI** | `https://<host>.<domain>/` |
| **n8n** | `https://n8n.<host>.<domain>/` |
| **MinIO API** | `https://s3.<host>.<domain>/` (nach Secured Mode nur intern) |
| **MinIO n8n-Bucket** | `https://s3.<host>.<domain>/n8n/` |

---

## JWT-Token für Bild-URLs aktivieren (Experimentell)

> ⚠️ **Hinweis:** Dieses Feature ist experimentell und funktioniert noch nicht vollständig.

### Bekannte Einschränkungen

Das KI-Modell liest die vollständigen URLs mit JWT-Token nicht immer korrekt aus dem RAG-System aus. Dies führt dazu, dass Bild-Links in Chat-Antworten teilweise nicht funktionieren. Die Ursache liegt vermutlich im Embedding-Prozess.

### Voraussetzungen

- JWT-Zertifikate wurden erstellt (siehe [JWT-Zertifikate](#jwt-zertifikate))
- MinIO ist konfiguriert (siehe [MinIO Konfiguration](#minio-konfiguration))

### Schritt 1: OCR-Workflow konfigurieren

1. Öffne n8n: `https://n8n.<host>.<domain>/`
2. Öffne den **OCR-Workflow**
3. Finde den Node **Enable signed URLs**
4. Ändere den Wert von `false` auf `true`
5. Workflow speichern und veröffentlichen

### Schritt 2: Nginx auf Secured Mode umstellen

```bash
cd /opt/ai-lab

# Aktuelles Template sichern
sudo mv nginx/templates/sites.conf.template nginx/templates/sites.conf.template.bak

# Secured Template aktivieren
sudo mv nginx/templates/sites.secured.conf.template nginx/templates/sites.conf.template

# Nginx neu starten
sudo docker compose restart nginx
```

### Schritt 3: Datenbank bereinigen (bei bestehenden Daten)

> ⚠️ **Wichtig:** Wurden bereits Bild-Links ohne JWT-Token erstellt, funktionieren diese nach der Aktivierung nicht mehr. In diesem Fall sollte die Datenbank neu erstellt werden.

1. Öffne n8n: `https://n8n.<host>.<domain>/`
2. Öffne den **GitLab AI Agent** Workflow
3. Führe den Node **Clear Tables** aus
4. Indexiere die Dokumente neu über das Form-Trigger

### Deaktivierung

Um JWT-Token wieder zu deaktivieren:

```bash
cd /opt/ai-lab

# Templates zurücktauschen
sudo mv nginx/templates/sites.conf.template nginx/templates/sites.secured.conf.template
sudo mv nginx/templates/sites.conf.template.bak nginx/templates/sites.conf.template

# Nginx neu starten
sudo docker compose restart nginx
```

Anschließend im OCR-Workflow den Node **Enable signed URLs** wieder auf `false` setzen.

---

## Troubleshooting

### Zertifikate erneuern nicht automatisch

```bash
# Manuell erneuern
sudo docker compose run --rm --entrypoint certbot certbot renew
sudo docker compose restart nginx
```

### Nginx startet nicht

```bash
# Logs prüfen
sudo docker compose logs nginx

# Config validieren
sudo docker compose exec nginx nginx -t
```

### Ollama-Modelle laden nicht

```bash
# Ollama-Logs prüfen
sudo docker compose logs ollama

# Manuell ein Modell laden
sudo docker compose exec ollama ollama pull llama3.1:8b
```

---

## Support

Bei Problemen:
1. Logs der betroffenen Services prüfen: `sudo docker compose logs <service>`
2. Issue im Repository erstellen