# TechRetail - Escalando hacia la Nube con Docker Swarm

## Descripción del Proyecto

TechRetail es una plataforma de comercio electrónico que migra su infraestructura a una arquitectura de microservicios contenerizada usando Docker Swarm para lograr alta disponibilidad, escalabilidad y balanceo de carga automático.

## Modos de Despliegue

Este proyecto soporta dos modos de despliegue:

### 1. Producción con Docker Swarm (Recomendado)
Despliegue en cluster con alta disponibilidad, escalabilidad y balanceo de carga.

### 2. Desarrollo Local
Despliegue simplificado para desarrollo y pruebas locales usando Docker Compose.

## Inicio Rápido

### Opción A: Despliegue Automático con Swarm

```bash
# Ejecutar el script de configuración automática
./setup.sh
```

### Opción B: Desarrollo Local

```bash
# Para desarrollo local
docker-compose -f docker-compose.yml -f docker-compose.override.yml up --build
```

### Opción C: Despliegue Manual con Swarm

Sigue las instrucciones detalladas en las secciones siguientes.

## Arquitectura

La aplicación consta de los siguientes microservicios:

- **Frontend**: Nginx alpine sirviendo la tienda en línea
- **Backend**: API REST en Node.js
- **Database**: MySQL 8 para persistencia de datos
- **Cache**: Redis para mejorar rendimiento
- **Visualizer**: Interfaz web para monitoreo del cluster Swarm

### Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────┐
│              DOCKER SWARM CLUSTER                   │
│                                                     │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐       │
│  │ Manager   │  │ Worker 1  │  │ Worker 2  │       │
│  │ Node      │  │ Node      │  │ Node      │       │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘       │
│        │              │              │             │
│        └──────────────┼──────────────┘             │
│                       │                            │
│  ┌────────────────────▼─────────────────────────┐  │
│  │         Red Overlay (techretail_net)         │  │
│  └──────┬──────────┬──────────┬──────────┬─────┘  │
│         │          │          │          │        │
│ [frontend] [backend] [database] [redis] [visualizer]
│ 3 réplicas 2 réplicas 1 réplica 1 réplica 1 réplica │
└─────────────────────────────────────────────────────┘
```

## Requisitos Previos

- Docker Engine 20.10+
- Docker Compose 2.0+
- Acceso a un cluster Docker Swarm (mínimo 1 manager + 2 workers)

## Configuración del Cluster Docker Swarm

### 1. Inicializar el Cluster (Nodo Manager)

```bash
# En el nodo manager, reemplaza <IP_MANAGER> con la IP del nodo manager
docker swarm init --advertise-addr <IP_MANAGER>
```

### 2. Obtener Token para Workers

```bash
docker swarm join-token worker
```

### 3. Unir Nodos Workers al Cluster

```bash
# En cada nodo worker, ejecuta el comando generado en el paso anterior
docker swarm join --token <TOKEN> <IP_MANAGER>:2377
```

### 4. Verificar Nodos del Cluster

```bash
docker node ls
```

## Despliegue de la Aplicación

### 1. Crear Secret

```bash
# Crear secret para la contraseña de base de datos y Redis
echo "techretail_pass" | docker secret create db_password -
```

### 2. Construir la Imagen del Backend

```bash
# Desde el directorio raíz del proyecto
docker build -t techretail_project-backend:latest ./backend
```

### 3. Desplegar el Stack

```bash
# Desplegar todos los servicios
docker stack deploy -c docker-compose.yml techretail
```

### 4. Verificar el Despliegue

```bash
# Ver servicios del stack
docker stack services techretail

# Ver réplicas de un servicio específico
docker service ps techretail_frontend
docker service ps techretail_backend
```

## Escalado Dinámico

### Escalar el Servicio Frontend

```bash
# Escalar frontend a 5 réplicas
docker service scale techretail_frontend=5

# Verificar el escalado
docker service ps techretail_frontend
```

### Escalar el Servicio Backend

```bash
# Escalar backend a 3 réplicas
docker service scale techretail_backend=3
```

## Desarrollo Local

Para desarrollo y pruebas locales, usa el archivo `docker-compose.override.yml`:

```bash
# Construir y ejecutar todos los servicios
docker-compose -f docker-compose.yml -f docker-compose.override.yml up --build

# Ejecutar en segundo plano
docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d --build

# Ver logs
docker-compose -f docker-compose.yml -f docker-compose.override.yml logs -f

# Detener servicios
docker-compose -f docker-compose.yml -f docker-compose.override.yml down
```

### Acceder en Desarrollo Local

- **Frontend**: http://localhost
- **API Backend**: http://localhost:3000
- **Visualizer**: http://localhost:8080
- **Base de datos**: localhost:3306
- **Redis**: localhost:6379

### Desarrollo del Backend

Para desarrollo del backend con hot reload:

```bash
cd backend
npm install
npm run dev
```

El código se monta como volumen, por lo que los cambios se reflejan automáticamente.

## Endpoints de la API

### Health Check
```bash
curl http://localhost:3000/health
```

### Información del Servicio
```bash
curl http://localhost:3000/info
```

### Productos
```bash
# Listar todos los productos
curl http://localhost:3000/products

# Obtener producto por ID
curl http://localhost:3000/products/1
```

### Órdenes
```bash
# Listar todas las órdenes
curl http://localhost:3000/orders

# Crear nueva orden (POST)
curl -X POST http://localhost:3000/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "Juan Pérez",
    "customer_email": "juan@example.com",
    "total": 299.99
  }'
```

## Monitoreo y Logs

### Ver Logs de Servicios

```bash
# Logs del backend
docker service logs techretail_backend

# Logs del frontend
docker service logs techretail_frontend

# Logs de la base de datos
docker service logs techretail_database
```

### Monitoreo con Visualizer

Accede a http://localhost:8080 para ver el estado del cluster en tiempo real.

## Gestión de Configuraciones

### Secrets (Datos Sensibles)
- `db_password`: Contraseña usada por MySQL y Redis

### Configs (Datos No Sensibles)
- `nginx_config`: Configuración de Nginx

## Limpieza y Mantenimiento

### Eliminar el Stack

```bash
docker stack rm techretail
```

### Eliminar Secrets

```bash
docker secret rm db_password
```

### Salir del Cluster

```bash
# En nodos workers
docker swarm leave

# En nodo manager (fuerza la salida)
docker swarm leave --force
```

## Solución de Problemas

### Problema: Servicios no se despliegan
```bash
# Verificar estado de servicios
docker stack services techretail

# Ver logs de servicios específicos
docker service logs <service_name>
```

### Problema: No se puede acceder a la aplicación
```bash
# Verificar que los puertos estén libres
netstat -tlnp | grep :80
netstat -tlnp | grep :8080

# Verificar servicios en ejecución
docker service ps techretail_frontend
```

### Problema: Conexión a base de datos falla
```bash
# Verificar que el servicio de base de datos esté ejecutándose
docker service ps techretail_database

# Verificar logs de la base de datos
docker service logs techretail_database
```

## Equipo de Desarrollo

- **Arquitectura**: Docker Swarm
- **Orquestación**: Servicios con réplicas
- **Redes**: Overlay network
- **Persistencia**: Volúmenes Docker
- **Seguridad**: Docker Secrets para credenciales

## Próximos Pasos

- Implementar health checks avanzados
- Configurar monitoreo con Prometheus/Grafana
- Implementar CI/CD con GitHub Actions
- Agregar balanceo de carga con Traefik
- Implementar logging centralizado con ELK Stack

---

**TechRetail** - Escalando hacia la nube con Docker Swarm 🚀