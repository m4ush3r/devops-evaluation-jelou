const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3000;

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'userdb',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  // AWS RDS optimized settings
  max: 10, // Maximum number of connections
  idleTimeoutMillis: 30000, // Close idle connections after 30 seconds
  connectionTimeoutMillis: 10000 // Connection timeout
});

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "blob:"],
      connectSrc: ["'self'"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
    },
  },
}));
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static('public'));

const initDB = async (retries = 5) => {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      // Test connection first
      await pool.query('SELECT 1');
      
      // Create table
      await pool.query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          email VARCHAR(255) UNIQUE NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('Database initialized successfully');
      return;
    } catch (error) {
      console.error(`Database initialization attempt ${attempt}/${retries} failed:`, error.message);
      
      if (attempt === retries) {
        console.error('Failed to initialize database after all retries');
        return;
      }
      
      // Wait before retry (exponential backoff)
      const delay = Math.min(1000 * Math.pow(2, attempt - 1), 10000);
      console.log(`Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
};

// Root route - API documentation
app.get('/', (req, res) => {
  res.json({
    message: 'User Management Microservice API',
    version: '1.0.0',
    endpoints: {
      health: 'GET /health',
      users: {
        list: 'GET /users',
        create: 'POST /users',
        get: 'GET /users/:id',
        update: 'PUT /users/:id',
        delete: 'DELETE /users/:id'
      }
    },
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Get all users
app.get('/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/users', async (req, res) => {
  try {
    const { name, email } = req.body;
    
    if (!name || !email) {
      return res.status(400).json({ error: 'Name and email are required' });
    }

    const result = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Email already exists' });
    }
    console.error('Error creating user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email } = req.body;
    
    if (!name || !email) {
      return res.status(400).json({ error: 'Name and email are required' });
    }

    const result = await pool.query(
      'UPDATE users SET name = $1, email = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
      [name, email, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json(result.rows[0]);
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Email already exists' });
    }
    console.error('Error updating user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.delete('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('DELETE FROM users WHERE id = $1 RETURNING *', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(PORT, async () => {
  console.log(`Server running on port ${PORT}`);
  await initDB();
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  pool.end(() => {
    process.exit(0);
  });
});