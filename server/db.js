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

// Expose a connect function that returns a Promise so callers can wait for DB readiness
function connect() {
    return new Promise((resolve, reject) => {
        con.connect(function (err) {
            if (err) {
                // If the database does not exist, create it and retry
                if (err && err.code === 'ER_BAD_DB_ERROR') {
                    console.warn(`Database '${DB_NAME}' not found. Attempting to create it...`);
                    const tmp = mysql.createConnection({
                        host: DB_HOST,
                        user: DB_USER,
                        password: DB_PASSWORD,
                        multipleStatements: true
                    });

                    const createSql = `CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`;
                    tmp.query(createSql, (createErr) => {
                        tmp.end();
                        if (createErr) {
                            console.error('Failed to create database:', createErr);
                            return reject(createErr);
                        }

                        // Retry connecting the original connection
                        con.connect(function (err2) {
                            if (err2) {
                                console.error('Error connecting after creating database:', err2);
                                return reject(err2);
                            }
                            console.log('Connected to mobi_app database as id ' + con.threadId);
                            resolve(con);
                        });
                    });
                    return;
                }

                console.error('Error connecting to mobi_app database:', err);
                return reject(err);
            }
            console.log('Connected to mobi_app database as id ' + con.threadId);
            resolve(con);
        });
    });
}

// Function to initialize database from mobi_app.sql (async/await)
async function initializeDatabase() {
    const sqlFilePath = path.join(__dirname, 'mobi_app.sql');

    if (!fs.existsSync(sqlFilePath)) {
        console.warn('Warning: mobi_app.sql file not found');
        return;
    }

    // Read and modify SQL to use CREATE TABLE IF NOT EXISTS
    let sql = fs.readFileSync(sqlFilePath, 'utf8');
    sql = sql.replace(/CREATE TABLE /g, 'CREATE TABLE IF NOT EXISTS ');

    // Split statements by semicolon and filter out empty ones
    const statements = sql.split(';').map(s => s.trim()).filter(Boolean);

    let executed = 0;
    let errors = 0;

    for (let i = 0; i < statements.length; i++) {
        const statement = statements[i];
        try {
            // Skip extremely short statements
            if (!statement || statement.length < 3) continue;
            await con.promise().query(statement);
            executed++;
        } catch (err) {
            // Ignore duplicate entry errors, warn on others
            if (err && err.message && err.message.includes('Duplicate entry')) {
                // ignore
            } else {
                errors++;
                console.warn(`Warning on statement ${i + 1}:`, err.message || err);
            }
        }
    }

    if (errors === 0) {
        console.log('✅ Database initialized successfully from mobi_app.sql');
    } else {
        console.log(`⚠️ Database initialized with ${errors} warnings (${executed} statements executed)`);
    }
}

// Export the raw connection object under module.exports, but expose the
// async helper as `ensureConnect` to avoid overwriting the native
// `con.connect` method on the connection instance.
module.exports = con;
module.exports.initializeDatabase = initializeDatabase;
module.exports.ensureConnect = connect;