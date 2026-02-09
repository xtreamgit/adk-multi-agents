# Admin Panel End-to-End Testing Plan

**Date:** January 9, 2026  
**Tester:** Manual Testing  
**Environment:** Local Development (localhost)

---

## Pre-Test Checklist

- [x] Backend running on port 8000
- [x] Frontend running on port 3000
- [ ] Logged in as admin user (alice)
- [ ] Database backed up (optional)

---

## Test Suite Overview

1. **Admin Dashboard Access** - Verify admin panel loads and displays stats
2. **User Management** - Create, edit, delete users and manage groups
3. **Group Management** - Create, edit, delete groups
4. **Role Management** - Create roles and assign to groups
5. **Navigation** - Test sidebar navigation between all pages
6. **Audit Logs** - Verify logging and filtering functionality
7. **Error Handling** - Test validation and error messages
8. **Permission Checks** - Verify access control works

---

## Test 1: Admin Dashboard Access

**URL:** `http://localhost:3000/admin`

### Steps:
1. Navigate to `/admin`
2. Verify page loads without errors
3. Check dashboard displays:
   - [ ] Total Users count
   - [ ] Active Users count
   - [ ] Total Groups count
   - [ ] Recent Users list
   - [ ] Active Sessions count
4. Verify sidebar navigation is visible
5. Verify "Back to App" link exists

**Expected Result:** Dashboard loads successfully with statistics and navigation

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 2: User Management - List Users

**URL:** `http://localhost:3000/admin/users`

### Steps:
1. Click "Users" in sidebar or navigate to `/admin/users`
2. Verify page loads without "Load failed" error
3. Check user table displays:
   - [ ] Username column
   - [ ] Full Name column
   - [ ] Email column
   - [ ] Groups column (with badges)
   - [ ] Status column (Active/Inactive)
   - [ ] Last Login column
   - [ ] Actions column (Edit, Groups, Delete buttons)
4. Verify existing users are displayed (alice, bob, charlie, etc.)

**Expected Result:** User list loads with all columns and data

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 3: User Management - Create User

### Steps:
1. Click "Add User" button
2. Verify "Create New User" dialog opens
3. Fill in form:
   - Username: `testuser_e2e`
   - Email: `testuser_e2e@example.com`
   - Full Name: `Test User E2E`
   - Password: `password123`
4. Select initial groups (e.g., "users")
5. Click "Create User"
6. Verify success message appears
7. Verify new user appears in table

**Expected Result:** User created successfully and appears in list

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 4: User Management - Edit User

### Steps:
1. Find `testuser_e2e` in the user list
2. Click "Edit" button
3. Verify "Edit User" dialog opens with pre-filled data
4. Modify Full Name to: `Test User E2E Updated`
5. Click "Update User"
6. Verify success message appears
7. Verify updated name appears in table

**Expected Result:** User updated successfully

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 5: User Management - Assign/Remove Groups

### Steps:
1. Find `testuser_e2e` in the user list
2. Click "Groups" button
3. Verify "Manage User Groups" dialog opens
4. Check current groups are displayed
5. Add user to "admin-users" group (select from dropdown, click "Add")
6. Verify success message
7. Verify "admin-users" badge appears in Available Groups
8. Remove user from "admin-users" (click X on badge)
9. Verify success message
10. Close dialog
11. Verify groups column in table reflects changes

**Expected Result:** Group assignments work correctly

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 6: User Management - Delete User

### Steps:
1. Find `testuser_e2e` in the user list
2. Click "Delete" button
3. Verify confirmation dialog appears
4. Confirm deletion
5. Verify success message appears
6. Verify user is removed from list OR marked as inactive

**Expected Result:** User deleted/deactivated successfully

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 7: User Management - Self-Deletion Prevention

### Steps:
1. Try to delete the currently logged-in user (alice)
2. Click "Delete" button
3. Verify error message: "You cannot delete yourself"

**Expected Result:** Self-deletion is prevented with error message

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 8: Group Management - List Groups

**URL:** `http://localhost:3000/admin/groups`

### Steps:
1. Click "Groups" in sidebar or navigate to `/admin/groups`
2. Verify page loads
3. Check Groups table displays:
   - [ ] Name column
   - [ ] Description column
   - [ ] Created At column
   - [ ] Actions column (Edit, Delete buttons)
4. Check Roles table displays:
   - [ ] Role Name column
   - [ ] Permissions column (with badges)
   - [ ] Actions column
5. Verify existing groups are displayed (admin-users, users, etc.)

**Expected Result:** Groups and roles lists load correctly

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 9: Group Management - Create Group

### Steps:
1. Click "Add Group" button
2. Verify "Create New Group" dialog opens
3. Fill in form:
   - Name: `test-group-e2e`
   - Description: `Test Group for E2E Testing`
4. Click "Create Group"
5. Verify success message appears
6. Verify new group appears in table

**Expected Result:** Group created successfully

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 10: Group Management - Edit Group

### Steps:
1. Find `test-group-e2e` in the groups list
2. Click "Edit" button
3. Verify "Edit Group" dialog opens with pre-filled data
4. Modify Description to: `Updated Test Group Description`
5. Click "Update Group"
6. Verify success message appears
7. Verify updated description appears in table

**Expected Result:** Group updated successfully

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 11: Role Management - Create Role

### Steps:
1. Click "Add Role" button
2. Verify "Create New Role" dialog opens
3. Fill in form:
   - Name: `test-role-e2e`
   - Description: `Test Role for E2E Testing`
4. Select permissions:
   - [x] view:audit_logs
   - [x] manage:users
5. Click "Create Role"
6. Verify success message appears
7. Verify new role appears in Roles table with permission badges

**Expected Result:** Role created successfully with permissions

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 12: Role Management - Assign Role to Group

### Steps:
1. Find a group row in the Groups table
2. Click "Roles" button for `test-group-e2e`
3. Verify "Manage Group Roles" dialog opens
4. Select `test-role-e2e` from dropdown
5. Click "Assign Role"
6. Verify success message appears
7. Verify role appears in the dialog's assigned roles list
8. Close dialog

**Expected Result:** Role assigned to group successfully

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 13: Role Management - Remove Role from Group

### Steps:
1. Click "Roles" button for `test-group-e2e`
2. Verify "Manage Group Roles" dialog opens
3. Find `test-role-e2e` in assigned roles
4. Click "Remove" button
5. Verify confirmation dialog
6. Confirm removal
7. Verify success message appears
8. Verify role is removed from assigned roles list

**Expected Result:** Role removed from group successfully

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 14: Group Management - Delete Group

### Steps:
1. Find `test-group-e2e` in the groups list
2. Click "Delete" button
3. Verify confirmation dialog appears
4. Confirm deletion
5. Verify success message appears
6. Verify group is removed from list

**Expected Result:** Group deleted successfully

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 15: Navigation - Sidebar Links

### Steps:
1. Starting from Dashboard (`/admin`)
2. Click each navigation link in order:
   - [ ] Dashboard → verify loads
   - [ ] Users → verify loads
   - [ ] Groups → verify loads
   - [ ] Corpora → verify loads (may not be implemented yet)
   - [ ] Permissions → verify loads (may not be implemented yet)
   - [ ] Audit Logs → verify loads
   - [ ] Sessions → verify loads (may not be implemented yet)
3. Verify active state highlighting works (current page is highlighted)
4. Click "Back to App" → verify returns to main app

**Expected Result:** All navigation links work and active states update

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 16: Audit Logs - View Logs

**URL:** `http://localhost:3000/admin/audit`

### Steps:
1. Navigate to `/admin/audit`
2. Verify page loads
3. Check audit log table displays:
   - [ ] Timestamp column
   - [ ] User column
   - [ ] Action column (with colored badge)
   - [ ] Details column
4. Verify logs from previous tests are visible (user created, group created, etc.)
5. Check pagination controls at bottom

**Expected Result:** Audit logs display with recent actions

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 17: Audit Logs - Filter by Action

### Steps:
1. On `/admin/audit` page
2. Open "Action" filter dropdown
3. Select "create" action type
4. Click "Apply Filters"
5. Verify only "create" actions are displayed (green badges)
6. Clear filter (select "all")
7. Verify all actions are displayed again

**Expected Result:** Filtering by action type works correctly

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 18: Audit Logs - Pagination

### Steps:
1. On `/admin/audit` page
2. If more than 50 logs exist:
   - [ ] Click "Next Page" button
   - [ ] Verify page 2 loads with different logs
   - [ ] Click "Previous Page" button
   - [ ] Verify page 1 loads again
3. If fewer than 50 logs:
   - [ ] Verify pagination controls are disabled/hidden

**Expected Result:** Pagination works correctly

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 19: Error Handling - Invalid User Creation

### Steps:
1. Go to `/admin/users`
2. Click "Add User"
3. Try to create user with existing username (e.g., "alice")
4. Fill in form with duplicate username
5. Click "Create User"
6. Verify error message appears (e.g., "Username already exists")
7. Verify user is NOT created

**Expected Result:** Validation error shown, user not created

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 20: Error Handling - Invalid Email Format

### Steps:
1. Go to `/admin/users`
2. Click "Add User"
3. Fill in form with invalid email (e.g., "notanemail")
4. Click "Create User"
5. Verify error message appears
6. Verify user is NOT created

**Expected Result:** Email validation error shown

**Status:** [ ] Pass [ ] Fail  
**Notes:**

---

## Test 21: Permission Check - Non-Admin Access

**Note:** This test requires a non-admin user account

### Steps:
1. Log out from alice account
2. Log in as a non-admin user (e.g., bob)
3. Try to navigate to `/admin`
4. Verify access is denied (403 error or redirect)

**Expected Result:** Non-admin users cannot access admin panel

**Status:** [ ] Pass [ ] Fail [ ] Skip  
**Notes:**

---

## Test Summary

**Total Tests:** 21  
**Passed:** ___  
**Failed:** ___  
**Skipped:** ___  

**Pass Rate:** ____%

---

## Critical Issues Found

1. 
2. 
3. 

---

## Minor Issues Found

1. 
2. 
3. 

---

## Recommendations

1. 
2. 
3. 

---

## Sign-off

**Tested By:** _______________  
**Date:** January 9, 2026  
**Status:** [ ] Ready for Production [ ] Needs Fixes [ ] Major Issues

---

## Next Steps

- [ ] Fix critical issues
- [ ] Re-test failed tests
- [ ] Deploy to staging environment
- [ ] Production deployment
