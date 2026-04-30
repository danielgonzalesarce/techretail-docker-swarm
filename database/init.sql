-- Script de inicialización de TechRetail Database
-- Crea la estructura inicial de tablas e inserta datos de ejemplo

-- Tabla de productos
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock INT DEFAULT 0,
    category VARCHAR(100),
    image_url VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_sku (sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de órdenes
CREATE TABLE IF NOT EXISTS orders (
    id VARCHAR(36) PRIMARY KEY,
    customer_name VARCHAR(255) NOT NULL,
    customer_email VARCHAR(255) NOT NULL,
    total DECIMAL(12, 2) NOT NULL,
    status ENUM('pending', 'processing', 'completed', 'cancelled') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_customer_email (customer_email),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de items de orden
CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id),
    INDEX idx_order_id (order_id),
    INDEX idx_product_id (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de logs de actividad
CREATE TABLE IF NOT EXISTS activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(255) NOT NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(100),
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar datos de ejemplo de productos
INSERT INTO products (sku, name, description, price, stock, category, image_url) VALUES
    ('TECH-001', 'Laptop XPS 15', 'Laptop de alto rendimiento con procesador Intel i9, 32GB RAM, SSD 1TB', 3499.99, 50, 'Laptops', 'https://placeholder.com/laptop-xps.jpg'),
    ('TECH-002', 'Monitor 4K 27"', 'Monitor Ultra HD 4K, 60Hz, Color Gamut 99% sRGB', 599.99, 75, 'Monitores', 'https://placeholder.com/monitor-4k.jpg'),
    ('TECH-003', 'Teclado Mecánico RGB', 'Teclado mecánico con switches Cherry MX, iluminación RGB programable', 149.99, 120, 'Accesorios', 'https://placeholder.com/keyboard-mech.jpg'),
    ('TECH-004', 'Mouse Inalámbrico', 'Mouse inalámbrico de precisión, batería 12 meses', 49.99, 200, 'Accesorios', 'https://placeholder.com/mouse-wireless.jpg'),
    ('TECH-005', 'Webcam 1080p', 'Webcam Full HD con micrófono incorporado, enfoque automático', 99.99, 85, 'Accesorios', 'https://placeholder.com/webcam-1080p.jpg'),
    ('TECH-006', 'Auriculares Inalámbricos', 'Auriculares Bluetooth, cancelación de ruido activa, batería 30h', 249.99, 100, 'Audio', 'https://placeholder.com/headphones-wireless.jpg'),
    ('TECH-007', 'SSD NVMe 2TB', 'SSD de alta velocidad NVMe Gen4, 7000 MB/s lectura', 199.99, 150, 'Almacenamiento', 'https://placeholder.com/ssd-nvme.jpg'),
    ('TECH-008', 'Hub USB-C 7en1', 'Adaptador USB-C multifunción con HDMI, USB 3.0, SD card', 79.99, 110, 'Accesorios', 'https://placeholder.com/usb-hub.jpg'),
    ('TECH-009', 'Fuente Modular 850W', 'Fuente de poder 850W 80+ Gold, cables modulares', 129.99, 60, 'Componentes', 'https://placeholder.com/psu-850w.jpg'),
    ('TECH-010', 'RAM DDR5 32GB', 'Memoria RAM DDR5 32GB (2x16GB) 5600MHz, RGB', 199.99, 95, 'Componentes', 'https://placeholder.com/ram-ddr5.jpg');

-- Crear índices adicionales para mejor rendimiento
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_stock ON products(stock);
CREATE INDEX idx_orders_customer_email ON orders(customer_email);

-- Ver estado de las tablas
SHOW TABLES;
SHOW TABLE STATUS;
