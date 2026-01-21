-- Migration: Add message counters to user_sessions table
-- This tracks the number of messages and user queries per session

-- Add message_count column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_sessions' 
        AND column_name = 'message_count'
    ) THEN
        ALTER TABLE user_sessions ADD COLUMN message_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- Add user_query_count column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_sessions' 
        AND column_name = 'user_query_count'
    ) THEN
        ALTER TABLE user_sessions ADD COLUMN user_query_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_user_sessions_message_count ON user_sessions(message_count);
