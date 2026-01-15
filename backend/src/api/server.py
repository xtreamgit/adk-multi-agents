"""
FastAPI server for the RAG Agent with user interface support.
"""

import uuid
import logging
import warnings
import os
import sqlite3
import json
from typing import Dict, List, Optional
from datetime import datetime, timedelta, timezone
from contextlib import contextmanager

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from passlib.context import CryptContext
from jose import JWTError, jwt

from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types

# Import new modular API routes
# Add src to path for proper imports
import sys
backend_src = os.path.join(os.path.dirname(os.path.dirname(__file__)))
if backend_src not in sys.path:
    sys.path.insert(0, backend_src)

# Now import after sys.path is set
from middleware.auth_middleware import get_current_user as get_current_user_from_middleware

# Import agent manager for dynamic agent loading (after path setup)
try:
    from services.agent_manager import AgentManager
    AGENT_MANAGER_AVAILABLE = True
    print("✅ AgentManager imported successfully")
except ImportError as e:
    AGENT_MANAGER_AVAILABLE = False
    print(f"⚠️  AgentManager not available: {e}")
    print("   Using static agent loading instead")

# Import database connection utilities (after path setup)
from database.connection import init_database, get_db_connection

try:
    from api.routes import (
        auth_router,
        users_router,
        groups_router,
        agents_router,
        corpora_router,
        admin_router,
        iap_auth_router
    )
    NEW_ROUTES_AVAILABLE = True
    print("✅ New API routes loaded successfully")
except ImportError as e:
    NEW_ROUTES_AVAILABLE = False
    print(f"⚠️  New API routes not available: {e}")
    print("   Run migrations and setup first: python src/database/migrations/run_migrations.py")

# Configure logging based on environment
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL))

# Suppress ADK warnings - these come from google.genai.types module
# The warning is hardcoded in the library and can't be suppressed via logging
# We need to suppress it at the warnings module level with the exact category
if not os.getenv("SHOW_ADK_WARNINGS", "false").lower() == "true":
    # Suppress the specific warning from google.genai.types
    warnings.filterwarnings("ignore", category=UserWarning, module="google.genai.types")
    warnings.filterwarnings("ignore", message=".*non-text parts in the response.*")
    logging.getLogger("google.genai.types").setLevel(logging.ERROR)

# Security configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

# Database configuration (now handled in connection.py)

def get_user_from_db(username: str) -> Optional[Dict]:
    """Get user from database by username."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, username, email, full_name, hashed_password, 
                   is_active, default_agent_id, google_id, auth_provider,
                   created_at, updated_at, last_login 
            FROM users WHERE username = ?
        """, (username,))
        row = cursor.fetchone()
        if row:
            return dict(row)
    return None

def create_user_in_db(username: str, full_name: str, email: str, hashed_password: str) -> Dict:
    """Create a new user in the database."""
    created_at = datetime.now(timezone.utc).isoformat()
    
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO users (username, full_name, email, hashed_password, created_at, last_login)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (username, full_name, email, hashed_password, created_at, None))
        conn.commit()
    
    return {
        "username": username,
        "full_name": full_name,
        "email": email,
        "created_at": created_at,
        "last_login": None
    }

def update_last_login(username: str):
    """Update the last login timestamp for a user."""
    last_login = datetime.now(timezone.utc).isoformat()
    
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET last_login = ? WHERE username = ?", (last_login, username))
        conn.commit()

def user_exists(username: str) -> bool:
    """Check if a user exists in the database."""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT 1 FROM users WHERE username = ? LIMIT 1", (username,))
        return cursor.fetchone() is not None

# Initialize database on startup
logger = logging.getLogger(__name__)
logger.info(f"🔍 Environment Check - DB_TYPE: {os.getenv('DB_TYPE', 'NOT SET')}")
# Skip SQLite migrations if using PostgreSQL (migrations already applied to Cloud SQL)
if os.getenv('DB_TYPE') == 'postgresql':
    logger.info("⏭️  Skipping SQLite migrations (using PostgreSQL Cloud SQL)")

# Setup admin group automatically
def setup_admin_group():
    """Create admin-users group and add first user to it if needed."""
    try:
        from database.repositories import GroupRepository, UserRepository
        from services.user_service import UserService
        
        # Create admin-users group if it doesn't exist
        admin_group = GroupRepository.get_group_by_name('admin-users')
        if not admin_group:
            admin_group = GroupRepository.create_group(
                name='admin-users',
                description='Administrators with full system access'
            )
            admin_group_id = admin_group['id']
            print(f"✅ Created admin-users group (ID: {admin_group_id})")
        else:
            admin_group_id = admin_group['id']
        
        # Get all users and add first user to admin group if they're not already
        all_users = UserRepository.get_all()
        if all_users:
            first_user_id = all_users[0]['id']
            user_groups = UserService.get_user_groups(first_user_id)
            if admin_group_id not in user_groups:
                UserService.add_user_to_group(first_user_id, admin_group_id)
                print(f"✅ Added user '{all_users[0]['username']}' to admin-users group")
    except Exception as e:
        print(f"⚠️  Admin group setup error (non-critical): {e}")

setup_admin_group()

# Pydantic models for API requests/responses
class UserProfile(BaseModel):
    name: str
    preferences: Optional[str] = None

class ChatMessage(BaseModel):
    message: str
    user_profile: Optional[UserProfile] = None
    corpora: Optional[List[str]] = None

class ChatResponse(BaseModel):
    response: str
    timestamp: datetime
    session_id: str

class SessionInfo(BaseModel):
    session_id: str
    user_profile: Optional[UserProfile] = None
    username: Optional[str] = None
    created_at: datetime
    last_activity: datetime

class User(BaseModel):
    id: int
    username: str
    full_name: str
    email: str
    created_at: str
    last_login: Optional[str] = None

class UserCreate(BaseModel):
    username: str
    password: str
    full_name: str
    email: str

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user: User

# Authentication functions
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            return None
        return username
    except JWTError:
        return None

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    """Get current authenticated user from token."""
    token = credentials.credentials
    username = verify_token(token)
    
    if username is None:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")
    
    user_data = get_user_from_db(username)
    if user_data is None:
        raise HTTPException(status_code=401, detail="User not found")
    
    # Ensure updated_at has a value (use created_at if NULL)
    updated_at = user_data.get("updated_at") or user_data.get("created_at")
    
    # Convert datetime objects to ISO strings for Pydantic
    def to_iso(dt):
        if dt is None:
            return None
        if isinstance(dt, str):
            return dt
        return dt.isoformat() if hasattr(dt, 'isoformat') else str(dt)
    
    return User(
        id=user_data["id"],
        username=user_data["username"],
        full_name=user_data["full_name"],
        email=user_data["email"],
        is_active=bool(user_data.get("is_active", True)),
        default_agent_id=user_data.get("default_agent_id"),
        google_id=user_data.get("google_id"),
        auth_provider=user_data.get("auth_provider", "local"),
        created_at=to_iso(user_data["created_at"]),
        updated_at=to_iso(updated_at),
        last_login=to_iso(user_data.get("last_login")),
    )

# In-memory session storage (in production, use Redis or database)
sessions: Dict[str, Dict] = {}

# Initialize ADK session service and runner
# Import after vertexai.init() to ensure proper initialization
import sys
import os

# Add config directory to path
backend_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
config_path = os.path.join(backend_root, 'config')
if config_path not in sys.path:
    sys.path.insert(0, config_path)
if backend_root not in sys.path:
    sys.path.insert(0, backend_root)

from config_loader import load_config

# Get account environment (defaults to 'develom')
account_env = os.environ.get("ACCOUNT_ENV", "develom")
print(f"🔧 Loading agent for account: {account_env}")

# Load account-specific configuration
config = load_config(account_env)

# Resolve effective configuration without overwriting existing environment
# This ensures deployment-provided env vars take precedence, while still
# making values available for downstream modules that read from os.environ
effective_project = os.getenv("PROJECT_ID") or config.PROJECT_ID
effective_location = os.getenv("GOOGLE_CLOUD_LOCATION") or config.LOCATION

# Populate env only if missing (do not override)
os.environ.setdefault("PROJECT_ID", effective_project)
os.environ.setdefault("GOOGLE_CLOUD_LOCATION", effective_location)

print(f"📋 Config resolved: PROJECT_ID={effective_project}, LOCATION={effective_location}")

# Log resolved environment for observability
logging.info(
    "backend_startup",
    extra={
        "account_env": account_env,
        "project_id": effective_project,
        "location": effective_location,
        "root_path": os.getenv("ROOT_PATH", ""),
    },
)

# Initialize AgentManager for dynamic agent loading
root_agent = None
if AGENT_MANAGER_AVAILABLE:
    agent_manager = AgentManager(
        project_id=effective_project,
        location=effective_location
    )
    print(f"✅ AgentManager initialized for dynamic agent loading")
    # Load default agent for backward compatibility and health checks (optional)
    try:
        root_agent, _ = agent_manager.get_agent_by_id(1)  # Default agent
        print(f"✅ Loaded default agent: {root_agent.name} with {len(root_agent.tools)} tools")
    except Exception as e:
        print(f"⚠️  Could not load default agent from AgentManager: {e}")
        print("   This is OK - agents will be loaded dynamically from database")
        print("   To add agents, use the admin panel or API endpoints")
        # Load agent from config as fallback
        from services.agent_loader import load_agent_config, create_agent_from_config
        agent_config = load_agent_config(account_env)
        root_agent = create_agent_from_config(agent_config, effective_project, effective_location)
        print(f"✅ Loaded agent from config as fallback: {root_agent.name}")
else:
    # AgentManager is required - no fallback
    print("❌ AgentManager not available")
    print("   Please run database migrations: python src/database/migrations/run_migrations.py")
    raise RuntimeError("AgentManager is required but not available")

session_service = InMemorySessionService()
runner = Runner(agent=root_agent, app_name="rag_agent_api", session_service=session_service)

# Support running behind a load balancer with per-agent path prefixes
# ROOT_PATH is set per Cloud Run service (e.g., /agent1, /agent2, /agent3)
app = FastAPI(
    title="RAG Agent API",
    description="REST API for the Vertex AI RAG Agent",
    version="1.0.0",
    root_path=os.getenv("ROOT_PATH", ""),
)

# Configure CORS for frontend access
frontend_url = os.getenv("FRONTEND_URL", "")
allowed_origins = ["http://localhost:3000", "http://127.0.0.1:3000"]
if frontend_url:
    allowed_origins.append(frontend_url)

# Debug logging for CORS configuration
print(f"CORS Configuration:")
print(f"  FRONTEND_URL env var: {frontend_url}")
print(f"  Allowed origins: {allowed_origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# Register New Modular API Routes
# ============================================================================
if NEW_ROUTES_AVAILABLE:
    app.include_router(auth_router)
    app.include_router(users_router)
    app.include_router(groups_router)
    app.include_router(agents_router)
    app.include_router(corpora_router)
    app.include_router(admin_router)
    app.include_router(iap_auth_router)
    print("🚀 New API Routes Registered:")
    print("  ✅ /api/auth/*        - Authentication (register, login, refresh)")
    print("  ✅ /api/users/*       - User Management (profile, preferences)")
    print("  ✅ /api/groups/*      - Groups & Roles (admin)")
    print("  ✅ /api/agents/*      - Agent Management (switching, access)")
    print("  ✅ /api/corpora/*     - Corpus Management (access, selection)")
    print("  ✅ /api/admin/*       - Admin Panel (corpus management, audit)")
    print("  ✅ /api/iap/*         - IAP Authentication (Google Cloud IAP)")
    print("="*70 + "\n")
    
    # Note: Old auth endpoints below are replaced by new routes
    # The new routes provide enhanced functionality with RBAC
else:
    print("⚠️  Using legacy authentication endpoints")
    print("   To enable new features, run: python src/database/migrations/run_migrations.py\n")

# ============================================================================
# Legacy Authentication Endpoints
# NOTE: These endpoints are REPLACED by the new auth_router if available.
# The new routes provide:
#   - Enhanced user profiles with preferences
#   - Role-based access control (RBAC)
#   - Better error handling and validation
# These are kept for backwards compatibility if new routes aren't loaded.
# ============================================================================

# Legacy endpoint - replaced by /api/auth/register in new routes
@app.post("/api/auth/register-legacy", response_model=User, include_in_schema=not NEW_ROUTES_AVAILABLE)
async def register_user(user_data: UserCreate):
    """Register a new user."""
    # Check if user already exists
    if user_exists(user_data.username):
        raise HTTPException(status_code=400, detail="Username already exists")
    
    # Create new user
    hashed_password = get_password_hash(user_data.password)
    created_user = create_user_in_db(user_data.username, user_data.full_name, user_data.email, hashed_password)
    
    # Return user without password
    # Convert datetime objects to ISO strings for Pydantic
    def to_iso(dt):
        if dt is None:
            return None
        if isinstance(dt, str):
            return dt
        return dt.isoformat() if hasattr(dt, 'isoformat') else str(dt)
    
    return User(
        id=created_user["id"],
        username=created_user["username"],
        full_name=created_user["full_name"],
        email=created_user["email"],
        is_active=bool(created_user.get("is_active", True)),
        default_agent_id=created_user.get("default_agent_id"),
        google_id=created_user.get("google_id"),
        auth_provider=created_user.get("auth_provider", "local"),
        created_at=to_iso(created_user["created_at"]),
        updated_at=to_iso(created_user.get("updated_at") or created_user.get("created_at")),
        last_login=to_iso(created_user.get("last_login")),
    )

# Legacy endpoint - replaced by /api/auth/login in new routes
@app.post("/api/auth/login-legacy", response_model=Token, include_in_schema=not NEW_ROUTES_AVAILABLE)
async def login_user(login_data: UserLogin):
    """Authenticate user and return JWT token."""
    # Check if user exists
    user_data = get_user_from_db(login_data.username)
    if not user_data:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    # Verify password
    if not verify_password(login_data.password, user_data["hashed_password"]):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    # Update last login
    update_last_login(login_data.username)
    
    # Create access token
    access_token = create_access_token(data={"sub": user_data["username"]})
    
    # Return token with user info
    # Ensure updated_at has a value (use created_at if NULL)
    updated_at = user_data.get("updated_at") or user_data.get("created_at")
    
    # Convert datetime objects to ISO strings for Pydantic
    def to_iso(dt):
        if dt is None:
            return None
        if isinstance(dt, str):
            return dt
        return dt.isoformat() if hasattr(dt, 'isoformat') else str(dt)
    
    user_info = User(
        id=user_data["id"],
        username=user_data["username"],
        full_name=user_data["full_name"],
        email=user_data["email"],
        is_active=bool(user_data.get("is_active", True)),
        default_agent_id=user_data.get("default_agent_id"),
        google_id=user_data.get("google_id"),
        auth_provider=user_data.get("auth_provider", "local"),
        created_at=to_iso(user_data["created_at"]),
        updated_at=to_iso(updated_at),
        last_login=to_iso(user_data.get("last_login")),
    )
    return Token(access_token=access_token, token_type="bearer", user=user_info)

# Legacy endpoint - replaced by /api/auth/me in new routes
@app.get("/api/auth/verify-legacy", response_model=User, include_in_schema=not NEW_ROUTES_AVAILABLE)
async def verify_user_token(current_user: User = Depends(get_current_user)):
    """Verify JWT token and return user info."""
    return current_user

@app.get("/api/auth/check-username/{username}")
async def check_username_exists(username: str):
    """Check if a username exists in the database."""
    exists = user_exists(username)
    return {"username": username, "exists": exists}

@app.get("/api/admin/users")
async def get_all_users(current_user: User = Depends(get_current_user)):
    """Get all users from the database (admin endpoint)."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT username, full_name, email, created_at, last_login 
                FROM users 
                ORDER BY created_at DESC
            """)
            rows = cursor.fetchall()
            
            users = []
            for row in rows:
                users.append({
                    "username": row["username"],
                    "full_name": row["full_name"],
                    "email": row["email"],
                    "created_at": row["created_at"],
                    "last_login": row["last_login"]
                })
            
            return {"users": users, "total_count": len(users)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error querying users: {str(e)}")

@app.get("/api/admin/user-stats")
async def get_user_stats(current_user: User = Depends(get_current_user)):
    """Get user statistics from the database."""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Total users
            cursor.execute("SELECT COUNT(*) as total FROM users")
            total_users = cursor.fetchone()["total"]
            
            # Users created today
            today = datetime.now(timezone.utc).date().isoformat()
            cursor.execute("SELECT COUNT(*) as today FROM users WHERE DATE(created_at) = ?", (today,))
            users_today = cursor.fetchone()["today"]
            
            # Users with recent login (last 7 days)
            week_ago = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
            cursor.execute("SELECT COUNT(*) as active FROM users WHERE last_login > ?", (week_ago,))
            active_users = cursor.fetchone()["active"]
            
            return {
                "total_users": total_users,
                "users_created_today": users_today,
                "active_users_last_week": active_users
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting user stats: {str(e)}")

@app.get("/api/admin/sessions")
async def get_all_sessions(current_user: User = Depends(get_current_user)):
    """Get all active sessions with user information."""
    try:
        session_list = []
        for session_id, session_data in sessions.items():
            session_list.append({
                "session_id": session_id,
                "username": session_data.get("username", "Unknown"),
                "created_at": session_data.get("created_at"),
                "last_activity": session_data.get("last_activity"),
                "chat_messages": len(session_data.get("chat_history", []))
            })
        
        # Sort by last activity (most recent first)
        session_list.sort(key=lambda x: x["last_activity"] if x["last_activity"] else datetime.min, reverse=True)
        
        return {"sessions": session_list, "total_sessions": len(session_list)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting sessions: {str(e)}")

@app.get("/")
async def root():
    """Basic health check endpoint."""
    return {"message": "RAG Agent API is running"}

@app.get("/api/health")
async def health_check():
    """Enhanced health check endpoint with region and deployment info."""
    import platform
    import subprocess
    
    # Get Cloud Run revision info
    revision = os.getenv("K_REVISION", "unknown")
    service = os.getenv("K_SERVICE", "unknown")
    
    # Get region info from metadata service (Cloud Run specific)
    try:
        result = subprocess.run(
            ["curl", "-s", "-H", "Metadata-Flavor: Google", 
             "http://metadata.google.internal/computeMetadata/v1/instance/zone"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout:
            # Extract region from zone (e.g., projects/123/zones/us-west1-a -> us-west1)
            zone_parts = result.stdout.strip().split('/')
            if len(zone_parts) > 0:
                zone = zone_parts[-1]
                service_region = '-'.join(zone.split('-')[:-1])  # Remove zone suffix
            else:
                service_region = "unknown"
        else:
            service_region = "unknown"
    except Exception:
        service_region = "unknown"
    
    return {
        "status": "healthy",
        "service": service,
        "revision": revision,
        "service_region": service_region,
        "vertexai_region": os.getenv("VERTEXAI_LOCATION", "unknown"),
        "google_cloud_location": os.getenv("GOOGLE_CLOUD_LOCATION", "unknown"),
        "account_env": os.getenv("ACCOUNT_ENV", "unknown"),
        "root_path": os.getenv("ROOT_PATH", ""),
        "project_id": os.getenv("PROJECT_ID", "unknown"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "python_version": platform.python_version(),
        "agent_name": getattr(root_agent, 'name', 'unknown') if 'root_agent' in globals() else 'not_loaded'
    }

@app.post("/api/sessions", response_model=SessionInfo)
async def create_session(user_profile: Optional[UserProfile] = None, current_user: User = Depends(get_current_user_from_middleware)):
    """Create a new user session with agent selection."""
    session_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    try:
        # Get user's default agent if AgentManager available
        agent_id = None
        agent_name = None
        agent_display_name = None
        
        if agent_manager:
            try:
                _, agent_data = agent_manager.get_agent_for_user(current_user.id)
                agent_id = agent_data['id']
                agent_name = agent_data['name']
                agent_display_name = agent_data['display_name']
                logging.info(f"Assigned agent {agent_name} (id={agent_id}) to session {session_id}")
            except Exception as e:
                logging.warning(f"Could not assign agent to session: {e}. Using default.")
        
        # Create ADK session
        session_service.create_session(
            app_name="rag_agent_api",
            user_id="api_user",
            session_id=session_id,
        )

        # Persist session to database using SessionService
        from services.session_service import SessionService
        from models.session import SessionCreate
        
        session_create_data = SessionCreate(
            session_id=session_id,
            user_id=current_user.id,
            active_agent_id=agent_id
        )
        SessionService.create_session(session_create_data)

        # Store session information with agent details (in-memory for quick access)
        sessions[session_id] = {
            "session_id": session_id,
            "user_profile": user_profile.model_dump() if user_profile else None,
            "username": current_user.username,
            "user_id": current_user.id,
            "agent_id": agent_id,
            "agent_name": agent_name,
            "agent_display_name": agent_display_name,
            "created_at": now,
            "last_activity": now,
            "chat_history": [],
        }

        logging.info(
            "session_created",
            extra={
                "session_id": session_id,
                "account_env": account_env,
                "username": current_user.username,
                "agent_id": agent_id,
                "agent_name": agent_name,
            },
        )

        return SessionInfo(
            session_id=session_id,
            user_profile=user_profile,
            username=current_user.username,
            created_at=now,
            last_activity=now,
        )
    except Exception as e:
        logging.error(
            f"session_creation_failed: {e}",
            extra={
                "session_id": session_id,
                "account_env": account_env,
                "username": current_user.username,
            },
        )
        raise

@app.get("/api/sessions/{session_id}", response_model=SessionInfo)
async def get_session(session_id: str, current_user: User = Depends(get_current_user_from_middleware)):
    """Get session information."""
    if session_id not in sessions:
        # Create a new session if it doesn't exist (handles server restarts)
        now = datetime.now(timezone.utc)
        session_service.create_session(
            app_name="rag_agent_api", 
            user_id="api_user", 
            session_id=session_id
        )
        sessions[session_id] = {
            "session_id": session_id,
            "user_profile": None,
            "username": current_user.username,
            "created_at": now,
            "last_activity": now,
            "chat_history": []
        }
    
    session = sessions[session_id]
    return SessionInfo(
        session_id=session_id,
        user_profile=UserProfile(**session["user_profile"]) if session["user_profile"] else None,
        username=session["username"],
        created_at=session["created_at"],
        last_activity=session["last_activity"]
    )

@app.put("/api/sessions/{session_id}/profile")
async def update_user_profile(session_id: str, user_profile: UserProfile, current_user: User = Depends(get_current_user_from_middleware)):
    """Update user profile for a session."""
    if session_id not in sessions:
        # Create a new session if it doesn't exist (handles server restarts)
        now = datetime.now()
        session_service.create_session(
            app_name="rag_agent_api", 
            user_id="api_user", 
            session_id=session_id
        )
        sessions[session_id] = {
            "session_id": session_id,
            "user_profile": None,
            "username": current_user.username,
            "created_at": now,
            "last_activity": now,
            "chat_history": []
        }
    
    sessions[session_id]["user_profile"] = user_profile.model_dump()
    sessions[session_id]["last_activity"] = datetime.now(timezone.utc)
    
    return {"message": "Profile updated successfully"}

@app.post("/api/sessions/{session_id}/chat", response_model=ChatResponse)
async def chat_with_agent(session_id: str, chat_message: ChatMessage, current_user: User = Depends(get_current_user_from_middleware)):
    """Send a message to the RAG agent and get a response."""
    if session_id not in sessions:
        # Create a new session if it doesn't exist (handles server restarts)
        now = datetime.now()
        
        # Get user's default agent if AgentManager available
        agent_id = None
        agent_name = None
        agent_display_name = None
        
        if agent_manager:
            try:
                _, agent_data = agent_manager.get_agent_for_user(current_user.id)
                agent_id = agent_data['id']
                agent_name = agent_data['name']
                agent_display_name = agent_data['display_name']
                logging.info(f"Assigned agent {agent_name} (id={agent_id}) to session {session_id}")
            except Exception as e:
                logging.warning(f"Could not assign agent to session: {e}. Using default.")
        
        session_service.create_session(
            app_name="rag_agent_api", 
            user_id="api_user", 
            session_id=session_id
        )
        sessions[session_id] = {
            "session_id": session_id,
            "user_profile": None,
            "username": current_user.username,
            "user_id": current_user.id,
            "agent_id": agent_id,
            "agent_name": agent_name,
            "agent_display_name": agent_display_name,
            "created_at": now,
            "last_activity": now,
            "chat_history": []
        }
    
    # Update last activity
    sessions[session_id]["last_activity"] = datetime.now(timezone.utc)
    
    # Store the user message in chat history
    user_message_entry = {
        "role": "user",
        "content": chat_message.message,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    sessions[session_id]["chat_history"].append(user_message_entry)
    
    # Update message count in database
    from database.connection import get_db_connection
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE user_sessions 
            SET message_count = message_count + 1,
                last_activity = ?
            WHERE session_id = ?
        """, (datetime.now(timezone.utc).isoformat(), session_id))
        conn.commit()
    
    # Prepare context from user profile if available
    user_context = ""
    if chat_message.user_profile:
        user_context = f"User Profile:\nName: {chat_message.user_profile.name}\n"
        if chat_message.user_profile.preferences:
            user_context += f"Preferences: {chat_message.user_profile.preferences}\n"
        user_context += "\n\n"
    
    # Add corpus context if corpora are specified
    print(f"\n{'='*60}")
    print(f"[CORPUS DEBUG] Received corpora from frontend: {chat_message.corpora}")
    print(f"[CORPUS DEBUG] Corpora is None: {chat_message.corpora is None}")
    print(f"[CORPUS DEBUG] Corpora length: {len(chat_message.corpora) if chat_message.corpora else 0}")
    print(f"{'='*60}\n")
    
    if chat_message.corpora and len(chat_message.corpora) > 0:
        corpus_list = ", ".join(chat_message.corpora)
        logging.info(f"[CORPUS DEBUG] User selected {len(chat_message.corpora)} corpora: {corpus_list}")
        user_context += f"\n{'='*80}\n"
        user_context += f"CRITICAL INSTRUCTION - READ THIS CAREFULLY:\n"
        user_context += f"The user has selected {len(chat_message.corpora)} corpora: {corpus_list}\n"
        user_context += f"You MUST use rag_multi_query with corpus_names={chat_message.corpora}\n"
        user_context += f"DO NOT use rag_query. DO NOT search only 'ai-books'.\n"
        user_context += f"Search ALL {len(chat_message.corpora)} corpora simultaneously.\n"
        user_context += f"{'='*80}\n\n"
    else:
        logging.info("[CORPUS DEBUG] No corpora specified in request")
        print("[CORPUS DEBUG WARNING] No corpora received - will use default behavior")
    
    # Combine user context with the message
    full_message = user_context + chat_message.message
    
    try:
        # Get the agent for this session
        session_agent = root_agent  # Default
        agent_id = sessions[session_id].get("agent_id")
        
        logging.info(f"Chat endpoint - session {session_id}: agent_id={agent_id}, agent_manager={'available' if agent_manager else 'not available'}")
        
        if agent_manager and agent_id:
            try:
                session_agent, agent_data = agent_manager.get_agent_by_id(agent_id)
                logging.info(f"Loaded agent '{agent_data['name']}' with {len(session_agent.tools)} tools for session {session_id}")
            except Exception as e:
                logging.error(f"Could not load session agent: {e}. Using default.", exc_info=True)
        
        # Create a runner with the session-specific agent
        session_runner = Runner(
            agent=session_agent,
            app_name="rag_agent_api",
            session_service=session_service
        )
        
        # Ensure ADK session exists - only create if it doesn't exist
        try:
            session_service.get_session(
                app_name="rag_agent_api", 
                user_id="api_user", 
                session_id=session_id
            )
        except:
            # Only create if session doesn't exist
            session_service.create_session(
                app_name="rag_agent_api", 
                user_id="api_user", 
                session_id=session_id
            )
        
        # Create user content for ADK
        user_content = types.Content(
            role='user', 
            parts=[types.Part(text=full_message)]
        )
        
        # Run the agent and collect response
        response_text = ""
        async for event in session_runner.run_async(
            user_id="api_user", 
            session_id=session_id, 
            new_message=user_content
        ):
            if event.is_final_response() and event.content and event.content.parts:
                for part in event.content.parts:
                    if hasattr(part, 'text') and part.text:
                        response_text += part.text
        
        # Store the agent response in chat history
        agent_message_entry = {
            "role": "assistant",
            "content": response_text,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        sessions[session_id]["chat_history"].append(agent_message_entry)
        
        # Update message count for agent response
        from database.connection import get_db_connection
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE user_sessions 
                SET message_count = message_count + 1,
                    last_activity = ?
                WHERE session_id = ?
            """, (datetime.now(timezone.utc).isoformat(), session_id))
            conn.commit()
        
        return ChatResponse(
            response=response_text,
            timestamp=datetime.now(timezone.utc),
            session_id=session_id
        )
        
    except Exception as e:
        import traceback
        error_details = f"Error processing request: {str(e)}"
        traceback_details = traceback.format_exc()
        print(f"CHAT ERROR: {error_details}")
        print(f"CHAT TRACEBACK: {traceback_details}")
        raise HTTPException(status_code=500, detail=error_details)

@app.get("/api/sessions/{session_id}/history")
async def get_chat_history(session_id: str, current_user: User = Depends(get_current_user_from_middleware)):
    """Get chat history for a session."""
    if session_id not in sessions:
        # Return empty history instead of 404 when session doesn't exist
        # This handles cases where server restarted and sessions were cleared
        return {"chat_history": []}
    
    return {"chat_history": sessions[session_id]["chat_history"]}

@app.delete("/api/sessions/{session_id}")
async def delete_session(session_id: str, current_user: User = Depends(get_current_user_from_middleware)):
    """Delete a session."""
    if session_id not in sessions:
        # Return success even if session doesn't exist (idempotent operation)
        return {"message": "Session deleted successfully"}
    
    del sessions[session_id]
    return {"message": "Session deleted successfully"}

# Legacy endpoint - replaced by /api/corpora/ in new routes (with enhanced access control)
@app.get("/api/corpora-legacy", include_in_schema=not NEW_ROUTES_AVAILABLE)
async def list_corpora(current_user: User = Depends(get_current_user)):
    """List all available corpora using the RAG agent."""
    try:
        # Create a temporary session for this request
        temp_session_id = str(uuid.uuid4())
        session_service.create_session(
            app_name="rag_agent_api", 
            user_id="api_user", 
            session_id=temp_session_id
        )
        
        # Create user content for listing corpora
        user_content = types.Content(
            role='user', 
            parts=[types.Part(text="list_corpora")]
        )
        
        # Run the agent and collect response
        response_text = ""
        async for event in runner.run_async(
            user_id="api_user", 
            session_id=temp_session_id, 
            new_message=user_content
        ):
            if event.is_final_response() and event.content and event.content.parts:
                for part in event.content.parts:
                    if hasattr(part, 'text') and part.text:
                        response_text += part.text
        
        return {"corpora": response_text}
        
    except Exception as e:
        import traceback
        error_details = f"Error listing corpora: {str(e)}"
        traceback_details = traceback.format_exc()
        print(f"CORPORA ERROR: {error_details}")
        print(f"CORPORA TRACEBACK: {traceback_details}")
        raise HTTPException(status_code=500, detail=error_details)

# Legacy endpoint - replaced by /api/corpora/ in new routes (with enhanced access control)
@app.post("/api/corpora-legacy", include_in_schema=not NEW_ROUTES_AVAILABLE)
async def create_corpus(corpus_name: str, current_user: User = Depends(get_current_user)):
    """Create a new corpus using the RAG agent."""
    try:
        # Create a temporary session for this request
        temp_session_id = str(uuid.uuid4())
        session_service.create_session(
            app_name="rag_agent_api", 
            user_id="api_user", 
            session_id=temp_session_id
        )
        
        # Create user content for creating corpus
        user_content = types.Content(
            role='user', 
            parts=[types.Part(text=f"create_corpus {corpus_name}")]
        )
        
        # Run the agent and collect response
        response_text = ""
        async for event in runner.run_async(
            user_id="api_user", 
            session_id=temp_session_id, 
            new_message=user_content
        ):
            if event.is_final_response() and event.content and event.content.parts:
                for part in event.content.parts:
                    if hasattr(part, 'text') and part.text:
                        response_text += part.text
        
        return {"message": f"Corpus '{corpus_name}' creation initiated", "details": response_text}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating corpus: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
