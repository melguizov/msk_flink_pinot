#!/bin/bash
# cleanup-poc.sh
# Script para limpiar/destruir la infraestructura POC

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Banner
echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    POC CLEANUP SCRIPT                       ║"
echo "║                  ⚠️  DESTRUCTIVE OPERATION                   ║"
echo "║                                                              ║"
echo "║  This will DESTROY all POC infrastructure and data!         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Cambiar al directorio POC
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$SCRIPT_DIR/../envs/poc"

log "Cambiando a directorio POC: $POC_DIR"
cd "$POC_DIR"

# Verificar que estamos en el directorio correcto
if [ ! -f "main.tf" ]; then
    error "❌ No se encuentra main.tf en el directorio POC"
    exit 1
fi

# Verificar estado actual
log "🔍 Verificando estado actual de la infraestructura..."

if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    warn "⚠️  No se encontró archivo de estado de Terraform"
    echo "Posibles razones:"
    echo "  - La infraestructura no ha sido desplegada"
    echo "  - El estado está en un backend remoto (S3)"
    echo "  - El archivo de estado fue eliminado"
    
    read -p "¿Continuar de todas formas? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Cleanup cancelado por el usuario"
        exit 0
    fi
fi

# Mostrar recursos actuales
log "📋 Recursos actuales en el estado:"
if terraform show -json 2>/dev/null | jq -r '.values.root_module.child_modules[]?.address' 2>/dev/null; then
    echo "Recursos encontrados en el estado"
else
    warn "No se pudieron listar los recursos actuales"
fi

# Confirmación de destrucción
echo -e "${RED}"
echo "⚠️  CONFIRMACIÓN REQUERIDA:"
echo "   - Se DESTRUIRÁ toda la infraestructura POC"
echo "   - Se PERDERÁN todos los datos almacenados"
echo "   - Esta operación NO se puede deshacer"
echo "   - Recursos afectados:"
echo "     • Amazon MSK cluster"
echo "     • Kinesis Analytics (Flink) application"
echo "     • EKS cluster y nodos"
echo "     • VPC, subnets, NAT gateway"
echo "     • Load balancers"
echo "     • Volúmenes EBS"
echo "     • Todos los datos de Pinot"
echo -e "${NC}"

echo -e "${YELLOW}"
echo "Escribe 'DESTROY' para confirmar la destrucción:"
echo -e "${NC}"
read -r CONFIRMATION

if [ "$CONFIRMATION" != "DESTROY" ]; then
    log "Cleanup cancelado por el usuario"
    exit 0
fi

# Ejecutar destrucción
log "🚨 Iniciando destrucción de infraestructura POC..."
START_TIME=$(date +%s)

# Crear plan de destrucción
log "📋 Creando plan de destrucción..."
if terraform plan -destroy -out=destroy.tfplan; then
    log "✅ Plan de destrucción creado"
else
    error "❌ Falló la creación del plan de destrucción"
    exit 1
fi

# Aplicar destrucción
log "💥 Ejecutando destrucción..."
if terraform apply destroy.tfplan; then
    END_TIME=$(date +%s)
    DESTROY_TIME=$((END_TIME - START_TIME))
    
    log "✅ Infraestructura POC destruida exitosamente en ${DESTROY_TIME} segundos"
    
    # Cleanup de archivos locales
    log "🧹 Limpiando archivos locales..."
    rm -f destroy.tfplan
    rm -f terraform.tfstate.backup
    
    # Opcional: limpiar directorio .terraform
    read -p "¿Limpiar directorio .terraform? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf .terraform
        log "✅ Directorio .terraform limpiado"
    fi
    
    echo -e "${GREEN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    CLEANUP COMPLETADO                        "
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    log "✅ Todos los recursos POC han sido destruidos"
    log "💰 Los cargos por recursos deberían detenerse inmediatamente"
    log "📊 Verifica la consola AWS para confirmar que no quedan recursos"
    
    echo -e "${BLUE}"
    echo "📋 VERIFICACIÓN RECOMENDADA:"
    echo "   1. Revisar AWS Console para recursos huérfanos"
    echo "   2. Verificar que no hay volúmenes EBS sin usar"
    echo "   3. Confirmar que Load Balancers fueron eliminados"
    echo "   4. Revisar Security Groups personalizados"
    echo "   5. Verificar que NAT Gateway fue eliminado"
    echo -e "${NC}"
    
else
    error "❌ Falló la destrucción de infraestructura"
    error "Algunos recursos pueden no haber sido eliminados"
    error "Revisa manualmente en la consola AWS"
    
    echo -e "${YELLOW}"
    echo "🔧 TROUBLESHOOTING:"
    echo "   1. Algunos recursos pueden tener dependencias"
    echo "   2. Ejecuta: terraform destroy -auto-approve"
    echo "   3. Elimina recursos manualmente si es necesario"
    echo "   4. Verifica que no hay recursos protegidos contra eliminación"
    echo -e "${NC}"
    
    exit 1
fi

log "🎉 Cleanup completado exitosamente!"
