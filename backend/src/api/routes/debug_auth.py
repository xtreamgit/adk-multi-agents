"""
Temporary debug endpoint to check what's happening with authentication
"""
from fastapi import APIRouter
from database.repositories.user_repository import UserRepository
from passlib.context import CryptContext

router = APIRouter(prefix="/api/debug", tags=["debug"])
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

@router.get("/check-alice")
async def check_alice():
    """Debug endpoint to check alice's data"""
    try:
        user_dict = UserRepository.get_by_username("alice")
        
        if not user_dict:
            return {"error": "User not found"}
        
        hashed_password = user_dict.get('hashed_password', '')
        
        # Test verification with both passwords
        test_password_1 = 'alice123'
        test_password_2 = 'AkdDB2024!SecurePass'
        
        verify_1 = pwd_context.verify(test_password_1, hashed_password)
        verify_2 = pwd_context.verify(test_password_2, hashed_password)
        
        return {
            "username": user_dict.get('username'),
            "email": user_dict.get('email'),
            "hash_length": len(hashed_password),
            "hash_prefix": hashed_password[:30],
            "hash_suffix": hashed_password[-10:],
            "full_hash": hashed_password,
            "verify_alice123": verify_1,
            "verify_AkdDB2024": verify_2,
            "hash_type": type(hashed_password).__name__
        }
    except Exception as e:
        return {"error": str(e)}
