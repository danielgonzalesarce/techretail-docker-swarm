#!/bin/bash

# TechRetail Docker Swarm Setup Script
# Este script automatiza la configuración del cluster y despliegue de la aplicación

set -e

echo "🚀 TechRetail - Configuración de Docker Swarm"
echo "=============================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes coloreados
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que Docker esté instalado y ejecutándose
check_docker() {
    print_status "Verificando instalación de Docker..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker no está instalado. Por favor instala Docker primero."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker no está ejecutándose. Por favor inicia el servicio de Docker."
        exit 1
    fi

    print_success "Docker está instalado y ejecutándose"
}

# Verificar que estamos en un entorno Swarm
check_swarm() {
    print_status "Verificando estado de Docker Swarm..."

    if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
        print_error "Este nodo no es parte de un cluster Docker Swarm."
        print_status "Ejecuta 'docker swarm init' en el nodo manager o 'docker swarm join' en los nodos workers."
        exit 1
    fi

    print_success "Docker Swarm está activo"
}

# Crear secrets
create_secrets() {
    print_status "Creando secrets para credenciales..."

    # Secret para base de datos
    if ! docker secret ls --format '{{.Name}}' | grep -q "^db_password$"; then
        echo "techretail_pass" | docker secret create db_password -
        print_success "Secret 'db_password' creado"
    else
        print_warning "Secret 'db_password' ya existe"
    fi

    # Secret para Redis
    if ! docker secret ls --format '{{.Name}}' | grep -q "^redis_password$"; then
        echo "techretail_redis_123" | docker secret create redis_password -
        print_success "Secret 'redis_password' creado"
    else
        print_warning "Secret 'redis_password' ya existe"
    fi
}

# Construir imagen del backend
build_backend() {
    print_status "Construyendo imagen del backend..."

    if [ -f "backend/Dockerfile" ]; then
        docker build -t techretail_project-backend:latest ./backend
        print_success "Imagen del backend construida"
    else
        print_error "Dockerfile del backend no encontrado"
        exit 1
    fi
}

# Desplegar stack
deploy_stack() {
    print_status "Desplegando stack de servicios..."

    if [ -f "docker-compose.yml" ]; then
        docker stack deploy -c docker-compose.yml techretail
        print_success "Stack 'techretail' desplegado"

        # Esperar a que los servicios estén listos
        print_status "Esperando a que los servicios estén listos..."
        sleep 10

        # Verificar servicios
        print_status "Verificando servicios desplegados..."
        docker stack services techretail
    else
        print_error "Archivo docker-compose.yml no encontrado"
        exit 1
    fi
}

# Verificar despliegue
verify_deployment() {
    print_status "Verificando despliegue..."

    # Verificar servicios
    local services=$(docker stack services techretail --format '{{.Name}}' | wc -l)
    if [ "$services" -ge 4 ]; then
        print_success "Todos los servicios están desplegados ($services servicios)"
    else
        print_warning "Solo $services servicios desplegados (esperados: 5+)"
    fi

    # Verificar réplicas
    print_status "Verificando réplicas de servicios..."

    # Frontend (3 réplicas)
    local frontend_replicas=$(docker service ps techretail_frontend -f "desired-state=running" --format '{{.CurrentState}}' | grep -c "Running")
    if [ "$frontend_replicas" -ge 3 ]; then
        print_success "Frontend: $frontend_replicas réplicas ejecutándose"
    else
        print_warning "Frontend: $frontend_replicas réplicas (esperadas: 3+)"
    fi

    # Backend (2 réplicas)
    local backend_replicas=$(docker service ps techretail_backend -f "desired-state=running" --format '{{.CurrentState}}' | grep -c "Running")
    if [ "$backend_replicas" -ge 2 ]; then
        print_success "Backend: $backend_replicas réplicas ejecutándose"
    else
        print_warning "Backend: $backend_replicas réplicas (esperadas: 2+)"
    fi

    # Database (1 réplica)
    local db_replicas=$(docker service ps techretail_database -f "desired-state=running" --format '{{.CurrentState}}' | grep -c "Running")
    if [ "$db_replicas" -ge 1 ]; then
        print_success "Database: $db_replicas réplicas ejecutándose"
    else
        print_warning "Database: $db_replicas réplicas (esperadas: 1+)"
    fi

    # Cache (1 réplica)
    local cache_replicas=$(docker service ps techretail_cache -f "desired-state=running" --format '{{.CurrentState}}' | grep -c "Running")
    if [ "$cache_replicas" -ge 1 ]; then
        print_success "Cache: $cache_replicas réplicas ejecutándose"
    else
        print_warning "Cache: $cache_replicas réplicas (esperadas: 1+)"
    fi
}

# Función principal
main() {
    echo "Iniciando configuración de TechRetail..."

    check_docker
    check_swarm
    create_secrets
    build_backend
    deploy_stack
    verify_deployment

    echo ""
    print_success "🎉 Configuración completada!"
    echo ""
    echo "Accede a tu aplicación en:"
    echo "  • Frontend: http://localhost"
    echo "  • Visualizer: http://localhost:8080"
    echo "  • API Backend: http://localhost:3000"
    echo ""
    echo "Comandos útiles:"
    echo "  • Ver servicios: docker stack services techretail"
    echo "  • Escalar frontend: docker service scale techretail_frontend=5"
    echo "  • Ver logs: docker service logs techretail_backend"
    echo "  • Eliminar stack: docker stack rm techretail"
}

# Manejo de argumentos
case "${1:-}" in
    "secrets")
        check_docker
        create_secrets
        ;;
    "build")
        check_docker
        build_backend
        ;;
    "deploy")
        check_docker
        check_swarm
        deploy_stack
        ;;
    "verify")
        check_docker
        check_swarm
        verify_deployment
        ;;
    "clean")
        print_status "Eliminando stack y secrets..."
        docker stack rm techretail 2>/dev/null || true
        docker secret rm db_password redis_password 2>/dev/null || true
        print_success "Stack y secrets eliminados"
        ;;
    *)
        main
        ;;
esac