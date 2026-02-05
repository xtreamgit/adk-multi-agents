-- Migration: 010_rename_roles_to_agent_types.sql
-- Description: Rename chatbot_roles to chatbot_agent_types and chatbot_permissions to chatbot_tools
-- This migration refactors the terminology from "roles" and "permissions" to "agent types" and "tools"
-- to better reflect the actual purpose of these entities.
--
-- Changes:
-- 1. chatbot_roles → chatbot_agent_types
-- 2. chatbot_permissions → chatbot_tools
-- 3. chatbot_role_permissions → chatbot_agent_type_tools
-- 4. chatbot_group_roles → chatbot_group_agent_types
-- 5. Update all foreign key column names accordingly
--
-- This migration is REVERSIBLE - see rollback script: 010_rollback_agent_types_to_roles.sql

BEGIN;

-- ============================================================================
-- STEP 1: Rename chatbot_roles to chatbot_agent_types
-- ============================================================================
ALTER TABLE chatbot_roles RENAME TO chatbot_agent_types;

-- Rename indexes
ALTER INDEX IF EXISTS idx_chatbot_roles_name RENAME TO idx_chatbot_agent_types_name;

-- ============================================================================
-- STEP 2: Rename chatbot_permissions to chatbot_tools
-- ============================================================================
ALTER TABLE chatbot_permissions RENAME TO chatbot_tools;

-- Rename indexes
ALTER INDEX IF EXISTS idx_chatbot_permissions_category RENAME TO idx_chatbot_tools_category;

-- ============================================================================
-- STEP 3: Rename chatbot_role_permissions to chatbot_agent_type_tools
-- ============================================================================
ALTER TABLE chatbot_role_permissions RENAME TO chatbot_agent_type_tools;

-- Rename columns in chatbot_agent_type_tools
ALTER TABLE chatbot_agent_type_tools RENAME COLUMN role_id TO agent_type_id;
ALTER TABLE chatbot_agent_type_tools RENAME COLUMN permission_id TO tool_id;

-- Rename indexes
ALTER INDEX IF EXISTS idx_chatbot_role_permissions_role RENAME TO idx_chatbot_agent_type_tools_agent_type;
ALTER INDEX IF EXISTS idx_chatbot_role_permissions_permission RENAME TO idx_chatbot_agent_type_tools_tool;

-- ============================================================================
-- STEP 4: Rename chatbot_group_roles to chatbot_group_agent_types
-- ============================================================================
ALTER TABLE chatbot_group_roles RENAME TO chatbot_group_agent_types;

-- Rename columns in chatbot_group_agent_types
ALTER TABLE chatbot_group_agent_types RENAME COLUMN chatbot_role_id TO chatbot_agent_type_id;

-- Rename indexes
ALTER INDEX IF EXISTS idx_chatbot_group_roles_group RENAME TO idx_chatbot_group_agent_types_group;
ALTER INDEX IF EXISTS idx_chatbot_group_roles_role RENAME TO idx_chatbot_group_agent_types_agent_type;

-- ============================================================================
-- STEP 5: Update sequences (if any)
-- ============================================================================
-- PostgreSQL automatically renames sequences with tables, but we'll verify
ALTER SEQUENCE IF EXISTS chatbot_roles_id_seq RENAME TO chatbot_agent_types_id_seq;
ALTER SEQUENCE IF EXISTS chatbot_permissions_id_seq RENAME TO chatbot_tools_id_seq;
ALTER SEQUENCE IF EXISTS chatbot_role_permissions_id_seq RENAME TO chatbot_agent_type_tools_id_seq;
ALTER SEQUENCE IF EXISTS chatbot_group_roles_id_seq RENAME TO chatbot_group_agent_types_id_seq;

-- ============================================================================
-- STEP 6: Update constraint names for clarity (optional but recommended)
-- ============================================================================
-- Note: PostgreSQL automatically updates foreign key constraints when tables are renamed,
-- but we can rename them for clarity

-- Get current constraint names and rename them
DO $$
DECLARE
    constraint_record RECORD;
BEGIN
    -- Rename foreign key constraints in chatbot_agent_type_tools
    FOR constraint_record IN 
        SELECT constraint_name 
        FROM information_schema.table_constraints 
        WHERE table_name = 'chatbot_agent_type_tools' 
        AND constraint_type = 'FOREIGN KEY'
    LOOP
        IF constraint_record.constraint_name LIKE '%role%' THEN
            EXECUTE format('ALTER TABLE chatbot_agent_type_tools RENAME CONSTRAINT %I TO %I',
                constraint_record.constraint_name,
                replace(constraint_record.constraint_name, 'role', 'agent_type'));
        END IF;
        IF constraint_record.constraint_name LIKE '%permission%' THEN
            EXECUTE format('ALTER TABLE chatbot_agent_type_tools RENAME CONSTRAINT %I TO %I',
                constraint_record.constraint_name,
                replace(constraint_record.constraint_name, 'permission', 'tool'));
        END IF;
    END LOOP;

    -- Rename foreign key constraints in chatbot_group_agent_types
    FOR constraint_record IN 
        SELECT constraint_name 
        FROM information_schema.table_constraints 
        WHERE table_name = 'chatbot_group_agent_types' 
        AND constraint_type = 'FOREIGN KEY'
    LOOP
        IF constraint_record.constraint_name LIKE '%role%' THEN
            EXECUTE format('ALTER TABLE chatbot_group_agent_types RENAME CONSTRAINT %I TO %I',
                constraint_record.constraint_name,
                replace(constraint_record.constraint_name, 'role', 'agent_type'));
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- VERIFICATION: Display renamed tables
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '=== Migration Complete ===';
    RAISE NOTICE 'Tables renamed:';
    RAISE NOTICE '  chatbot_roles → chatbot_agent_types';
    RAISE NOTICE '  chatbot_permissions → chatbot_tools';
    RAISE NOTICE '  chatbot_role_permissions → chatbot_agent_type_tools';
    RAISE NOTICE '  chatbot_group_roles → chatbot_group_agent_types';
    RAISE NOTICE '';
    RAISE NOTICE 'Columns renamed:';
    RAISE NOTICE '  role_id → agent_type_id';
    RAISE NOTICE '  permission_id → tool_id';
    RAISE NOTICE '  chatbot_role_id → chatbot_agent_type_id';
    RAISE NOTICE '';
    RAISE NOTICE 'All data preserved. Foreign keys automatically updated.';
END $$;

COMMIT;
