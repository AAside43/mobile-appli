const mysql = require('mysql2');
const fs = require('fs');
const path = require('path');

// Read DB config from environment variables with sensible defaults
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_USER = process.env.DB_USER || 'root';
const DB_PASSWORD = process.env.DB_PASSWORD || '';
const DB_NAME = process.env.DB_NAME || 'mobi_app';

// Database connection to mobi_app database
const con = mysql.createConnection({
    host: DB_HOST,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME,
    multipleStatements: true // Allow multiple SQL statements
});

// Test the connection
con.connect(function(err) {
    if (err) {
        console.error('Error connecting to mobi_app database: ' + err.stack);
        return;
    }
    console.log('Connected to mobi_app database as id ' + con.threadId);
    
    // Auto-migrate: Add image column if it doesn't exist
    const addImageColumn = `
        ALTER TABLE rooms 
        ADD COLUMN IF NOT EXISTS image LONGTEXT
    `;
    
    con.query(addImageColumn, function(err) {
        if (err && !err.message.includes('Duplicate column')) {
            console.warn('Note: Image column migration skipped or already exists');
        } else {
            console.log('✅ Database schema updated: image column added to rooms table');
        }
    });
});

// Export the connection
module.exports = con;