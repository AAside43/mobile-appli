const mysql = require("mysql2");
const fs = require('fs');
const path = require('path');

// Database connection to mobi_app database
const con = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'mobi_app', // This connects to the mobi_app database
    multipleStatements: true // Allow multiple SQL statements
});

// Test the connection
con.connect(function(err) {
    if (err) {
        console.error('Error connecting to mobi_app database: ' + err.stack);
        return;
    }
    console.log('Connected to mobi_app database as id ' + con.threadId);
});

// Function to initialize database from mobi_app.sql
function initializeDatabase() {
    const sqlFilePath = path.join(__dirname, 'mobi_app.sql');
    
    if (!fs.existsSync(sqlFilePath)) {
        console.warn('Warning: mobi_app.sql file not found');
        return;
    }
    
    // Read and modify SQL to use CREATE TABLE IF NOT EXISTS
    let sql = fs.readFileSync(sqlFilePath, 'utf8');
    
    // Replace CREATE TABLE with CREATE TABLE IF NOT EXISTS
    sql = sql.replace(/CREATE TABLE /g, 'CREATE TABLE IF NOT EXISTS ');
    
    // Split by INSERT statements to avoid duplicate data
    const statements = sql.split(';').filter(stmt => stmt.trim());
    
    // Execute statements one by one
    let executed = 0;
    let errors = 0;
    
    statements.forEach((statement, index) => {
        if (statement.trim()) {
            con.query(statement, function(err) {
                if (err) {
                    // Ignore duplicate entry errors
                    if (!err.message.includes('Duplicate entry')) {
                        errors++;
                        console.warn(`Warning on statement ${index + 1}:`, err.message);
                    }
                } else {
                    executed++;
                }
                
                // Log success when all statements are processed
                if (index === statements.length - 1) {
                    if (errors === 0) {
                        console.log('✅ Database initialized successfully from mobi_app.sql');
                    } else {
                        console.log('⚠️ Database initialized with ${errors} warnings (${executed} statements executed');
                    }
                }
            });
        }
    });
}

module.exports = con;
module.exports.initializeDatabase = initializeDatabase;