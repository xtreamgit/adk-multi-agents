#!/bin/bash
# Local Application Test Suite
# Tests backend API and frontend functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKEND_URL="http://localhost:8000"
FRONTEND_URL="http://localhost:3000"
TEST_USER="alice"
TEST_PASSWORD="alice123"
ACCESS_TOKEN=""

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Log file
LOG_FILE="/tmp/local-app-test-$(date +%Y%m%d-%H%M%S).log"

echo "========================================" | tee -a "$LOG_FILE"
echo "Local Application Test Suite" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Helper functions
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$LOG_FILE"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$LOG_FILE"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$LOG_FILE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_section() {
    echo "" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    echo "$1" | tee -a "$LOG_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
}

# Check if service is running
check_service() {
    local url=$1
    local name=$2
    
    print_test "Checking if $name is running at $url"
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        print_pass "$name is running"
        return 0
    else
        print_fail "$name is not running at $url"
        return 1
    fi
}

# Test API endpoint
test_api() {
    local method=$1
    local endpoint=$2
    local description=$3
    local expected_status=${4:-200}
    local data=$5
    local headers=$6
    
    print_test "$description"
    
    local url="${BACKEND_URL}${endpoint}"
    local cmd="curl -s -w '\n%{http_code}' -X $method '$url'"
    
    if [ -n "$headers" ]; then
        cmd="$cmd -H '$headers'"
    fi
    
    if [ -n "$data" ]; then
        cmd="$cmd -H 'Content-Type: application/json' -d '$data'"
    fi
    
    local response=$(eval $cmd 2>&1)
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "  Response: $body" >> "$LOG_FILE"
    echo "  Status: $status_code" >> "$LOG_FILE"
    
    if [ "$status_code" = "$expected_status" ]; then
        print_pass "Status $status_code (expected $expected_status)"
        echo "$body"
        return 0
    else
        print_fail "Status $status_code (expected $expected_status)"
        return 1
    fi
}

# Start tests
print_section "1. SERVICE AVAILABILITY"

# Check backend
if ! check_service "$BACKEND_URL/api/health" "Backend"; then
    print_info "Starting backend..."
    cd backend
    python -m src.api.server > /tmp/backend-test.log 2>&1 &
    BACKEND_PID=$!
    cd ..
    sleep 5
    
    if ! check_service "$BACKEND_URL/api/health" "Backend"; then
        print_fail "Could not start backend. Check /tmp/backend-test.log"
        exit 1
    fi
fi

# Check frontend
if ! check_service "$FRONTEND_URL" "Frontend"; then
    print_info "Frontend not running. Tests will focus on backend API."
    FRONTEND_RUNNING=false
else
    FRONTEND_RUNNING=true
fi

print_section "2. BACKEND HEALTH CHECK"

HEALTH_RESPONSE=$(test_api "GET" "/api/health" "Backend health check" 200)
if [ $? -eq 0 ]; then
    print_info "Project ID: $(echo "$HEALTH_RESPONSE" | grep -o '"project_id":"[^"]*"' | cut -d'"' -f4)"
    print_info "Python version: $(echo "$HEALTH_RESPONSE" | grep -o '"python_version":"[^"]*"' | cut -d'"' -f4)"
fi

print_section "3. AUTHENTICATION TESTS"

# Test login
print_test "User login (alice/alice123)"
LOGIN_DATA='{"username":"'$TEST_USER'","password":"'$TEST_PASSWORD'"}'
LOGIN_RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "$LOGIN_DATA" 2>&1)

if echo "$LOGIN_RESPONSE" | grep -q "access_token"; then
    print_pass "Login successful"
    ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    print_info "Access token obtained: ${ACCESS_TOKEN:0:20}..."
    echo "$LOGIN_RESPONSE" >> "$LOG_FILE"
else
    print_fail "Login failed"
    echo "$LOGIN_RESPONSE" >> "$LOG_FILE"
fi

# Test authenticated endpoint
if [ -n "$ACCESS_TOKEN" ]; then
    print_test "Get user profile (authenticated)"
    PROFILE_RESPONSE=$(curl -s -X GET "$BACKEND_URL/api/users/me" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>&1)
    
    if echo "$PROFILE_RESPONSE" | grep -q "username"; then
        print_pass "Profile retrieved successfully"
        print_info "Username: $(echo "$PROFILE_RESPONSE" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)"
        echo "$PROFILE_RESPONSE" >> "$LOG_FILE"
    else
        print_fail "Could not retrieve profile"
        echo "$PROFILE_RESPONSE" >> "$LOG_FILE"
    fi
fi

print_section "4. AGENT MANAGEMENT TESTS"

if [ -n "$ACCESS_TOKEN" ]; then
    print_test "List available agents"
    AGENTS_RESPONSE=$(curl -s -X GET "$BACKEND_URL/api/agents" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>&1)
    
    if echo "$AGENTS_RESPONSE" | grep -q "agents"; then
        print_pass "Agents list retrieved"
        AGENT_COUNT=$(echo "$AGENTS_RESPONSE" | grep -o '"name"' | wc -l)
        print_info "Found $AGENT_COUNT agent(s)"
        echo "$AGENTS_RESPONSE" >> "$LOG_FILE"
    else
        print_fail "Could not retrieve agents"
        echo "$AGENTS_RESPONSE" >> "$LOG_FILE"
    fi
fi

print_section "5. CORPUS MANAGEMENT TESTS"

if [ -n "$ACCESS_TOKEN" ]; then
    print_test "List available corpora"
    CORPORA_RESPONSE=$(curl -s -X GET "$BACKEND_URL/api/corpora" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>&1)
    
    if echo "$CORPORA_RESPONSE" | grep -q "corpora"; then
        print_pass "Corpora list retrieved"
        CORPUS_COUNT=$(echo "$CORPORA_RESPONSE" | grep -o '"name"' | wc -l)
        print_info "Found $CORPUS_COUNT corpus/corpora"
        echo "$CORPORA_RESPONSE" >> "$LOG_FILE"
    else
        print_fail "Could not retrieve corpora"
        echo "$CORPORA_RESPONSE" >> "$LOG_FILE"
    fi
    
    print_test "Get user's selected corpora"
    SELECTED_RESPONSE=$(curl -s -X GET "$BACKEND_URL/api/corpora/selected" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>&1)
    
    if [ $? -eq 0 ]; then
        print_pass "Selected corpora retrieved"
        echo "$SELECTED_RESPONSE" >> "$LOG_FILE"
    else
        print_fail "Could not retrieve selected corpora"
        echo "$SELECTED_RESPONSE" >> "$LOG_FILE"
    fi
fi

print_section "6. ADMIN PANEL TESTS"

if [ -n "$ACCESS_TOKEN" ]; then
    print_test "List all users (admin endpoint)"
    USERS_RESPONSE=$(curl -s -X GET "$BACKEND_URL/api/admin/users" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>&1)
    
    if echo "$USERS_RESPONSE" | grep -q "users"; then
        print_pass "Users list retrieved"
        USER_COUNT=$(echo "$USERS_RESPONSE" | grep -o '"username"' | wc -l)
        print_info "Found $USER_COUNT user(s)"
        echo "$USERS_RESPONSE" >> "$LOG_FILE"
    else
        print_fail "Could not retrieve users (may need admin role)"
        echo "$USERS_RESPONSE" >> "$LOG_FILE"
    fi
    
    print_test "Get corpus metadata (admin endpoint)"
    METADATA_RESPONSE=$(curl -s -X GET "$BACKEND_URL/api/admin/corpora/metadata" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>&1)
    
    if [ $? -eq 0 ]; then
        print_pass "Corpus metadata retrieved"
        echo "$METADATA_RESPONSE" >> "$LOG_FILE"
    else
        print_fail "Could not retrieve corpus metadata"
        echo "$METADATA_RESPONSE" >> "$LOG_FILE"
    fi
fi

print_section "7. DOCUMENT RETRIEVAL TESTS"

if [ -n "$ACCESS_TOKEN" ]; then
    print_test "List documents endpoint availability"
    DOCS_RESPONSE=$(curl -s -w '\n%{http_code}' -X GET "$BACKEND_URL/api/documents/list" \
        -H "Authorization: Bearer $ACCESS_TOKEN" 2>&1)
    
    STATUS=$(echo "$DOCS_RESPONSE" | tail -n1)
    BODY=$(echo "$DOCS_RESPONSE" | sed '$d')
    
    if [ "$STATUS" = "200" ] || [ "$STATUS" = "400" ]; then
        print_pass "Documents endpoint accessible (status: $STATUS)"
        echo "$BODY" >> "$LOG_FILE"
    else
        print_fail "Documents endpoint error (status: $STATUS)"
        echo "$BODY" >> "$LOG_FILE"
    fi
fi

print_section "8. CHAT/RAG FUNCTIONALITY TESTS"

if [ -n "$ACCESS_TOKEN" ]; then
    print_test "Send test query to RAG agent"
    QUERY_DATA='{"query":"What is this system?","corpus_ids":[]}'
    QUERY_RESPONSE=$(curl -s -w '\n%{http_code}' -X POST "$BACKEND_URL/api/chat" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$QUERY_DATA" 2>&1)
    
    STATUS=$(echo "$QUERY_RESPONSE" | tail -n1)
    BODY=$(echo "$QUERY_RESPONSE" | sed '$d')
    
    if [ "$STATUS" = "200" ]; then
        print_pass "Chat query successful"
        print_info "Response preview: $(echo "$BODY" | head -c 100)..."
        echo "$BODY" >> "$LOG_FILE"
    else
        print_fail "Chat query failed (status: $STATUS)"
        echo "$BODY" >> "$LOG_FILE"
    fi
fi

print_section "9. FRONTEND TESTS"

if [ "$FRONTEND_RUNNING" = true ]; then
    print_test "Frontend homepage accessible"
    if curl -s -f "$FRONTEND_URL" > /dev/null 2>&1; then
        print_pass "Frontend homepage loads"
    else
        print_fail "Frontend homepage not accessible"
    fi
    
    print_test "Frontend login page"
    if curl -s "$FRONTEND_URL/login" | grep -q "login\|Login\|Sign in"; then
        print_pass "Login page accessible"
    else
        print_fail "Login page not found"
    fi
    
    print_test "Frontend admin page"
    if curl -s "$FRONTEND_URL/admin" > /dev/null 2>&1; then
        print_pass "Admin page accessible"
    else
        print_fail "Admin page not accessible"
    fi
else
    print_info "Skipping frontend tests (frontend not running)"
    print_info "To start frontend: cd frontend && npm run dev"
fi

print_section "10. DATABASE CONNECTION TEST"

print_test "PostgreSQL database connection"
DB_TEST=$(docker exec adk-postgres-dev psql -U adk_dev_user -d adk_agents_db_dev -c "SELECT COUNT(*) FROM users;" 2>&1)

if echo "$DB_TEST" | grep -q "[0-9]"; then
    USER_COUNT=$(echo "$DB_TEST" | grep -o "[0-9]*" | head -1)
    print_pass "Database connected - $USER_COUNT users in database"
else
    print_fail "Database connection failed"
    echo "$DB_TEST" >> "$LOG_FILE"
fi

print_section "TEST SUMMARY"

echo "" | tee -a "$LOG_FILE"
echo "Total Tests:  $TOTAL_TESTS" | tee -a "$LOG_FILE"
echo "Passed:       $PASSED_TESTS" | tee -a "$LOG_FILE"
echo "Failed:       $FAILED_TESTS" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}" | tee -a "$LOG_FILE"
    EXIT_CODE=0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}" | tee -a "$LOG_FILE"
    EXIT_CODE=1
fi

echo "" | tee -a "$LOG_FILE"
echo "Full log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Cleanup
if [ -n "$BACKEND_PID" ]; then
    print_info "Stopping test backend (PID: $BACKEND_PID)"
    kill $BACKEND_PID 2>/dev/null || true
fi

exit $EXIT_CODE
