-- Add image column to rooms table to store base64 encoded images
-- Run this SQL to update your existing database

ALTER TABLE rooms ADD COLUMN IF NOT EXISTS image LONGTEXT;

-- The LONGTEXT type can store up to 4GB of text data, which is sufficient for base64 encoded images
