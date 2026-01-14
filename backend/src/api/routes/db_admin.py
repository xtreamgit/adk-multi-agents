"""
Temporary database admin endpoint for fixing password hashes
WARNING: This should be removed or secured after use
"""
from fastapi import APIRouter, HTTPException
from database.connection import get_db_connection
from passlib.context import CryptContext

router = APIRouter(prefix="/api/db-admin", tags=["db-admin"])
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

@router.post("/reset-passwords")
async def reset_passwords():
    """Reset passwords for test users to known values"""
    try:
        users_to_reset = [
            ("alice", "alice123"),
            ("bob", "bob123"),
            ("admin", "admin123"),
        ]
        
        with get_db_connection() as conn:
            cursor = conn.cursor()
            results = []
            
            for username, password in users_to_reset:
                # Generate fresh bcrypt hash
                hashed = pwd_context.hash(password)
                
                # Update password
                cursor.execute(
                    "UPDATE users SET hashed_password = ? WHERE username = ?",
                    (hashed, username)
                )
                
                # Verify update
                cursor.execute(
                    "SELECT username, email, is_active FROM users WHERE username = ?",
                    (username,)
                )
                user = cursor.fetchone()
                
                if user:
                    results.append({
                        "username": user["username"],
                        "email": user["email"],
                        "is_active": user["is_active"],
                        "status": "updated"
                    })
            
            conn.commit()
            
        return {
            "success": True,
            "message": f"Reset {len(results)} user passwords",
            "users": results
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to reset passwords: {str(e)}")


@router.get("/test-connection")
async def test_connection():
    """Test database connection and return basic info"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) as count FROM users")
            result = cursor.fetchone()
            
            return {
                "success": True,
                "connection": "working",
                "user_count": result["count"] if result else 0
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Connection test failed: {str(e)}")
