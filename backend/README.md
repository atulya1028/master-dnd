# Master DND Backend (Node.js + Express + MongoDB)

Production-ready backend API service powering the **Master DND** Flutter mobile application with phone OTP authentication, user profiles, DND profiles, rules, and insights.

---

## Features

- **Phone + OTP Authentication**: Real-world phone number authentication flow with 6-digit OTP verification and JWT session tokens.
- **Production Architecture**: Organized into `config/`, `controllers/`, `middleware/`, `models/`, `routes/`, and `utils/`.
- **MongoDB + Mongoose**: Full schema models for Users, OTPs, DND Profiles, and DND Rules with automatic indexing and timestamps.
- **Resilient Fallback Mode**: If MongoDB is not running locally during development, the server seamlessly falls back to an in-memory development repository so the app can be developed without blockers.
- **Security & Performance**: Helmet HTTP security headers, CORS enabled, Express rate limiting on sensitive auth endpoints, and centralized error handling.

---

## Getting Started

### 1. Prerequisites
- **Node.js**: v18+ (tested on Node 24)
- **MongoDB**: Local MongoDB instance (`mongodb://127.0.0.1:27017/master_dnd`) or MongoDB Atlas URI.

### 2. Install Dependencies
```bash
cd backend
npm install
```

### 3. Environment Variables
Create a `.env` file (copied from `.env.example`):
```env
PORT=5001
MONGODB_URI=mongodb://127.0.0.1:27017/master_dnd
JWT_SECRET=master_dnd_super_secret_jwt_key_2026
JWT_EXPIRES_IN=30d
NODE_ENV=development
FIXED_DEV_OTP=123456
```

### 4. Run the Server
```bash
# Production start
npm start

# Development mode with hot auto-restart
npm run dev
```

---

## API Documentation

### Base URL
`http://localhost:5001/api` (or your machine's IP e.g. `http://10.0.2.2:5001/api` for Android Emulator)

### 1. Authentication (`/api/auth`)

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/send-otp` | Request a 6-digit OTP to phone number | No |
| `POST` | `/resend-otp` | Resend a fresh OTP | No |
| `POST` | `/verify-otp` | Verify OTP code and receive JWT session token | No |

#### Request: `POST /api/auth/send-otp`
```json
{
  "phone": "+19876543210"
}
```

#### Response:
```json
{
  "success": true,
  "message": "OTP sent successfully to +19876543210.",
  "phone": "+19876543210",
  "expiresInSeconds": 300,
  "testOtp": "381638"
}
```

#### Request: `POST /api/auth/verify-otp`
```json
{
  "phone": "+19876543210",
  "otp": "381638"
}
```

#### Response:
```json
{
  "success": true,
  "message": "Account created successfully",
  "token": "eyJhbGciOiJIUzI1Ni...",
  "isNewUser": true,
  "isProfileComplete": false,
  "user": {
    "id": "...",
    "phone": "+19876543210",
    "name": "",
    "email": "",
    "avatar": "A",
    "isProfileComplete": false,
    "dndEnabled": false
  }
}
```

---

### 2. User Profile (`/api/user`)
*All endpoints require header: `Authorization: Bearer <token>`*

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/profile` | Get current authenticated user profile |
| `PUT` | `/profile` | Setup or edit profile (name, email, avatar, emergency contacts) |
| `DELETE` | `/account` | Delete user account and associated DND data |

#### Request: `PUT /api/user/profile`
```json
{
  "name": "Atulya Agrawal",
  "email": "atulya@example.com",
  "avatar": "A",
  "bio": "Mobile Product Lead"
}
```

---

### 3. DND Profiles & Control (`/api/dnd`)
*All endpoints require header: `Authorization: Bearer <token>`*

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/profiles` | List all DND profiles for the user |
| `POST` | `/profiles` | Create a new custom DND profile |
| `PUT` | `/profiles/:id` | Update profile settings or set as active |
| `DELETE` | `/profiles/:id` | Delete profile |
| `POST` | `/toggle` | Toggle the Master DND power switch (`enabled: true/false`) |
| `GET` | `/rules` | Get active automation rules |
| `GET` | `/insights` | Get statistics, silenced counts, let through callers |
