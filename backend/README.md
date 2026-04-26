# GestureApp Backend

Node.js REST API for the GestureApp iOS dating application.

## Stack

| Layer | Technology |
|-------|------------|
| Runtime | Node.js 18+ |
| Framework | Express 4 |
| Database | PostgreSQL 15 in Russian infrastructure |
| Object storage | VK Cloud Object Storage (S3-compatible) |
| Auth | VK ID access token → custom JWT (default 7 days) |

---

## Quick Start (local)

```bash
# 1. Install dependencies
npm install

# 2. Configure environment
cp .env.example .env
#    → fill in DATABASE_URL and JWT_SECRET at minimum

# 3. Apply database schema (run once)
psql $DATABASE_URL -f schema.sql

# 4. Start the server
npm run dev        # watches for changes
# or
npm start          # production
```

Then update `APIConfig.baseURL` in the iOS app:
```swift
// GestureApp/Core/Backend/APIConfig.swift
static let baseURL = URL(string: "http://localhost:3000/api/v1")!
```

---

## Production for Russia

Recommended baseline:

- API: VK Cloud VM / Yandex Cloud Compute / Selectel VM in Russia
- Database: managed PostgreSQL in Russia
- Media: VK Cloud Object Storage or Yandex Object Storage
- TLS: nginx + Let's Encrypt or provider certificate
- Logs and backups: also inside Russian infrastructure

Files prepared for production:

- [.env.example](/Users/delevopermax/Documents/DevWeb/GestureApp/backend/.env.example)
- [nginx.gestureapp.conf](/Users/delevopermax/Documents/DevWeb/GestureApp/backend/deploy/nginx.gestureapp.conf)
- [gestureapp-api.service](/Users/delevopermax/Documents/DevWeb/GestureApp/backend/deploy/gestureapp-api.service)

## Deployment on VK Cloud / Yandex Cloud

### 1. Create a Postgres database

1. Open [VK Cloud Console](https://mcs.mail.ru) → **Cloud Databases** → **Create instance**
2. Choose PostgreSQL 15, select a region (ru-msk-1)
3. Copy the connection string and set `DATABASE_URL` in your environment

### 2. Create an Object Storage bucket

1. **Cloud Storage** → **Create bucket**
2. Set name (e.g. `gesture-media`), region `ru-msk-1`
3. Create an **Access Key** (Сервисный аккаунт → ключи)
4. Fill in `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET`, `CDN_BASE`

Prefer a private bucket plus controlled delivery, even if your CDN later exposes media publicly.

### 3. Deploy the API

You can run the API on:
- **VK Cloud Containers** (recommended – autoscaling)
- **VK Cloud VM** (simple, cheapest)

#### Option A – VK Cloud VM (Ubuntu 22.04)

```bash
# On the VM:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs
sudo useradd --system --create-home --shell /usr/sbin/nologin gestureapp

git clone <your-repo> /opt/gesture-api
cd /opt/gesture-api/backend
npm ci --omit=dev

# Configure environment
cp .env.example .env
# edit .env with Russian production values

# Install systemd service
sudo cp deploy/gestureapp-api.service /etc/systemd/system/gestureapp-api.service
sudo systemctl daemon-reload
sudo systemctl enable --now gestureapp-api
```

Then configure nginx:

```bash
sudo cp deploy/nginx.gestureapp.conf /etc/nginx/sites-available/gestureapp-api.conf
sudo ln -s /etc/nginx/sites-available/gestureapp-api.conf /etc/nginx/sites-enabled/gestureapp-api.conf
sudo nginx -t
sudo systemctl reload nginx
```

After that issue TLS for `api.example.ru` and switch the nginx `server_name` plus your iOS `baseURL`.

#### Option B – Docker

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
ENV PORT=3000
EXPOSE 3000
CMD ["node", "server.js"]
```

---

## API Reference

### Authentication
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/auth/vk` | — | Exchange VK access token for JWT |

**Request:** `{ "access_token": "..." }`  
**Response:** `{ "token": "...", "vk_user_id": 123 }`

### Profile
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/profile/me` | ✓ | Fetch own profile |
| PUT | `/api/v1/profile/me` | ✓ | Save/update own profile |
| DELETE | `/api/v1/profile/me` | ✓ | Delete own profile, matches and messages |
| POST | `/api/v1/media/avatar` | ✓ | Upload avatar (multipart/form-data, field: `file`) |
| POST | `/api/v1/media/video` | ✓ | Upload video intro (multipart/form-data, field: `file`) |

### Feed & Swipe
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/feed?limit=20` | ✓ | Random unswept candidate profiles |
| POST | `/api/v1/swipes` | ✓ | Submit swipe decision |

**Swipe request:** `{ "target_id": "uuid", "liked": true }`  
**Swipe response:** `{ "matched": true, "match": { ... } }`

### Matches & Chat
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/matches` | ✓ | All matches with embedded profile + last message |
| GET | `/api/v1/matches/:id/messages` | ✓ | Messages in a match (oldest first) |
| POST | `/api/v1/matches/:id/messages` | ✓ | Send a message |

---

## iOS Configuration Checklist

After deploying, switch the app to the Russian production domain:

1. **`GestureApp/Core/Backend/APIConfig.swift`**
   ```swift
   static let baseURL = URL(string: "https://api.example.ru/api/v1")!
   ```

2. Add the real `VKClientSecret` only through local build settings / `Info.plist` overrides.
   Do not commit it to git.

3. **`GestureApp/Info.plist`** – update URL scheme:
   ```xml
   <string>vkYOUR_VK_APP_ID</string>
   ```

## Before Russian release

- Replace placeholder consent texts with final legal documents and links
- Register the personal data operator workflow and internal incident process
- Keep DB, object storage, logs and backups in Russia
- Rotate the VK secret that was previously committed
- Verify account deletion also removes media objects from storage
