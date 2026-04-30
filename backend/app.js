const express = require('express');
const mysql = require('mysql2/promise');
const redis = require('redis');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Configuración
const config = {
  db: {
    host: process.env.DB_HOST || 'database',
    user: process.env.DB_USER || 'techretail_user',
    password: fs.existsSync('/run/secrets/db_password') 
      ? fs.readFileSync('/run/secrets/db_password', 'utf8').trim()
      : (process.env.DB_PASSWORD || 'techretail_pass'),
    database: process.env.DB_NAME || 'techretail_db',
    port: 3306
  },
  redis: {
    host: process.env.REDIS_HOST || 'cache',
    port: process.env.REDIS_PORT || 6379,
    password: fs.existsSync('/run/secrets/redis_password')
      ? fs.readFileSync('/run/secrets/redis_password', 'utf8').trim()
      : (process.env.REDIS_PASSWORD || 'techretail_redis_123')
  }
};

// Variables globales
let redisClient = null;
let pool = null;

// Inicializar conexiones
async function initializeConnections() {
  try {
    // Inicializar pool de MySQL
    pool = mysql.createPool({
      host: config.db.host,
      user: config.db.user,
      password: config.db.password,
      database: config.db.database,
      port: config.db.port,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });
    console.log('✓ Conectado a MySQL en', config.db.host);

    // Inicializar Redis
    console.log('Intentando conectar a Redis en:', config.redis.host, config.redis.port);
    redisClient = redis.createClient({
      url: `redis://:${config.redis.password}@${config.redis.host}:${config.redis.port}`,
      legacyMode: true
    });
    console.log('Cliente Redis creado');

    await redisClient.connect();
    console.log('✓ Conectado a Redis en', config.redis.host);
  } catch (error) {
    console.error('✗ Error en inicialización:', error.message);
    setTimeout(initializeConnections, 5000); // Reintentar en 5 segundos
  }
}

// Rutas

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'TechRetail Backend'
  });
});

// Info
app.get('/info', (req, res) => {
  res.json({
    service: 'TechRetail Backend API',
    version: '1.0.0',
    hostname: require('os').hostname(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'production',
    connected: {
      database: pool !== null,
      redis: redisClient !== null
    }
  });
});

// Productos - Listar todos
app.get('/products', async (req, res) => {
  try {
    // Intentar obtener del cache
    const cached = await redisClient.get('products:all');
    if (cached) {
      return res.json(JSON.parse(cached));
    }

    // Si no está en cache, obtener de la BD
    const connection = await pool.getConnection();
    const [products] = await connection.query('SELECT * FROM products LIMIT 50');
    connection.release();

    // Guardar en cache por 5 minutos
    await redisClient.setEx('products:all', 300, JSON.stringify(products));

    res.json(products);
  } catch (error) {
    console.error('Error al obtener productos:', error);
    res.status(500).json({ error: 'Error al obtener productos' });
  }
});

// Productos - Obtener por ID
app.get('/products/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const cacheKey = `products:${id}`;
    const cached = await redisClient.get(cacheKey);
    if (cached) {
      return res.json(JSON.parse(cached));
    }

    const connection = await pool.getConnection();
    const [products] = await connection.query('SELECT * FROM products WHERE id = ?', [id]);
    connection.release();

    if (products.length === 0) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }

    await redisClient.setEx(cacheKey, 300, JSON.stringify(products[0]));
    res.json(products[0]);
  } catch (error) {
    console.error('Error al obtener producto:', error);
    res.status(500).json({ error: 'Error al obtener producto' });
  }
});

// Ordenes - Crear nueva orden
app.post('/orders', async (req, res) => {
  const { customer_name, customer_email, products: orderProducts, total } = req.body;

  if (!customer_name || !customer_email || !orderProducts) {
    return res.status(400).json({ error: 'Datos incompletos' });
  }

  try {
    const orderId = uuidv4();
    const connection = await pool.getConnection();

    await connection.query(
      'INSERT INTO orders (id, customer_name, customer_email, total, status, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
      [orderId, customer_name, customer_email, total, 'pending']
    );

    // Guardar items de la orden
    for (const product of orderProducts) {
      await connection.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (?, ?, ?, ?)',
        [orderId, product.id, product.quantity, product.price]
      );
    }

    connection.release();

    // Invalidar cache
    await redisClient.del('orders:all');

    res.status(201).json({
      id: orderId,
      message: 'Orden creada exitosamente',
      customer_name,
      total,
      status: 'pending'
    });
  } catch (error) {
    console.error('Error al crear orden:', error);
    res.status(500).json({ error: 'Error al crear orden' });
  }
});

// Ordenes - Listar todas
app.get('/orders', async (req, res) => {
  try {
    const cached = await redisClient.get('orders:all');
    if (cached) {
      return res.json(JSON.parse(cached));
    }

    const connection = await pool.getConnection();
    const [orders] = await connection.query('SELECT * FROM orders ORDER BY created_at DESC LIMIT 100');
    connection.release();

    await redisClient.setEx('orders:all', 600, JSON.stringify(orders));
    res.json(orders);
  } catch (error) {
    console.error('Error al obtener órdenes:', error);
    res.status(500).json({ error: 'Error al obtener órdenes' });
  }
});

// Estadísticas
app.get('/stats', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    
    const [productCount] = await connection.query('SELECT COUNT(*) as count FROM products');
    const [orderCount] = await connection.query('SELECT COUNT(*) as count FROM orders');
    const [totalRevenue] = await connection.query('SELECT SUM(total) as total FROM orders WHERE status = "completed"');
    
    connection.release();

    res.json({
      products: productCount[0].count,
      orders: orderCount[0].count,
      totalRevenue: totalRevenue[0].total || 0,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error al obtener estadísticas:', error);
    res.status(500).json({ error: 'Error al obtener estadísticas' });
  }
});

// Cache stats
app.get('/cache/stats', async (req, res) => {
  try {
    const info = await redisClient.info('stats');
    res.json({ redis: info });
  } catch (error) {
    console.error('Error al obtener stats de cache:', error);
    res.status(500).json({ error: 'Error al obtener stats de cache' });
  }
});

// Clear cache
app.delete('/cache/clear', async (req, res) => {
  try {
    await redisClient.flushDb();
    res.json({ message: 'Cache limpiado exitosamente' });
  } catch (error) {
    console.error('Error al limpiar cache:', error);
    res.status(500).json({ error: 'Error al limpiar cache' });
  }
});

// Manejo de errores global
app.use((err, req, res, next) => {
  console.error('Error no manejado:', err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// Iniciar servidor
async function start() {
  await initializeConnections();
  
  app.listen(PORT, () => {
    console.log(`\n╔═══════════════════════════════════════╗`);
    console.log(`║  🚀 TechRetail Backend API          ║`);
    console.log(`║  Escuchando en puerto: ${PORT}              ║`);
    console.log(`║  Hostname: ${require('os').hostname().padEnd(20)}║`);
    console.log(`║  Ambiente: ${(process.env.NODE_ENV || 'production').padEnd(17)}║`);
    console.log(`╚═══════════════════════════════════════╝\n`);
  });
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM recibido, cerrando gracefully...');
  process.exit(0);
});

start().catch(error => {
  console.error('Error fatal:', error);
  process.exit(1);
});
