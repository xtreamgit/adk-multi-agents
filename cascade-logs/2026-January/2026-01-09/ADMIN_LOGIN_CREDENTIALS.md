# Admin Panel Login Credentials

**Date:** January 9, 2026  
**Status:** Authentication Re-enabled

---

## 🔐 Login Credentials

### Admin Users

Both users have been reset to the same password:

**Username:** `alice`  
**Password:** `AdminPass123!`

**Username:** `admin`  
**Password:** `AdminPass123!`

Both users are members of the `admin-users` group and have full admin access.

---

## 🚀 How to Access Admin Panel

### Step 1: Login to Frontend

1. Navigate to: `http://localhost:3000/landing`
2. Enter credentials:
   - Username: `alice` (or `admin`)
   - Password: `AdminPass123!`
3. Click "Login"

### Step 2: Access Admin Dashboard

After successful login, navigate to:
```
http://localhost:3000/admin
```

---

## 📋 What You Should See

### Dashboard (`/admin`)
- Total Users count
- Users Created Today count
- Active Users Last Week count
- Recent Users list
- Active Sessions list (may be empty)

### Users Page (`/admin/users`)
- List of all users with their groups
- Create, edit, delete user buttons
- Assign/remove groups

### Groups Page (`/admin/groups`)
- List of all groups
- Create, edit, delete group buttons
- Role management

### Sessions Page (`/admin/sessions`)
- List of all sessions in the system
- Session details and statistics

### Audit Logs (`/admin/audit`)
- Activity logs
- Filtering options

---

## 🔧 Authentication Flow

1. **Login** → Frontend sends credentials to `/api/auth/login`
2. **Token Received** → JWT token stored in localStorage
3. **API Requests** → Token sent in `Authorization: Bearer <token>` header
4. **Backend Validates** → Checks token and verifies user is in `admin-users` group
5. **Access Granted** → Admin endpoints return data

---

## 🐛 If Login Fails

### Check Backend Logs
```bash
# Backend should be running on port 8000
curl http://localhost:8000/api/health
```

### Test Login Directly
```bash
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "alice", "password": "AdminPass123!"}'
```

Should return:
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user": {
    "id": 2,
    "username": "alice",
    ...
  }
}
```

### Clear Browser Storage
If experiencing issues:
1. Open browser DevTools (F12)
2. Go to Application → Storage → Local Storage
3. Clear `auth_token` and `session_id`
4. Try logging in again

---

## 📝 Password Reset Script

If you need to reset passwords again:

```bash
cd backend
python reset_admin_password.py
```

This will reset both `alice` and `admin` passwords to `AdminPass123!`

---

## ✅ Testing Checklist

- [ ] Login to frontend with alice credentials
- [ ] Navigate to `/admin` - dashboard loads
- [ ] Click "Users" - users page loads
- [ ] Click "Groups" - groups page loads
- [ ] Click "Sessions" - sessions page loads
- [ ] Click "Audit Logs" - audit page loads
- [ ] Logout and login again - still works

---

## 🔒 Security Notes

**IMPORTANT:** The password `AdminPass123!` is for **testing only**. In production:
- Use strong, unique passwords
- Implement password rotation policies
- Enable multi-factor authentication
- Use environment variables for sensitive data
- Implement rate limiting on login endpoint
