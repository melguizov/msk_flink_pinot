#!/bin/bash
# deploy-5h-poc.sh
# Script para desplegar POC por 5 horas con auto-destrucción
# Costo estimado: ~$2.00 USD

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
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    POC 5-Hour Deployment                     ║"
echo "║              MSK + Flink + Pinot on AWS                     ║"
echo "║                                                              ║"
echo "║  💰 Estimated Cost: ~\$2.00 USD for 5 hours                  ║"
echo "║  ⏰ Auto-destruction: Enabled                                ║"
echo "║  🎯 Purpose: Proof of Concept / Demo                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar dependencias
log "Verificando dependencias..."

if ! command -v terraform &> /dev/null; then
    error "Terraform no está instalado"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    error "AWS CLI no está instalado"
    exit 1
fi

if ! command -v at &> /dev/null; then
    warn "Comando 'at' no disponible. Auto-destrucción manual requerida."
    AUTO_DESTROY=false
else
    AUTO_DESTROY=true
fi

# Verificar credenciales AWS
log "Verificando credenciales AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
    error "Credenciales AWS no configuradas correctamente"
    exit 1
fi

# Cambiar al directorio POC
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$SCRIPT_DIR/../envs/poc"

log "Cambiando a directorio POC: $POC_DIR"
cd "$POC_DIR"

# Confirmar despliegue
echo -e "${YELLOW}"
echo "⚠️  CONFIRMACIÓN REQUERIDA:"
echo "   - Se desplegará infraestructura AWS"
echo "   - Costo estimado: ~\$2.00 USD por 5 horas"
echo "   - Recursos: MSK, Flink, EKS, VPC, ALB"
echo "   - Auto-destrucción: $(if [ "$AUTO_DESTROY" = true ]; then echo "Habilitada"; else echo "Manual"; fi)"
echo -e "${NC}"

read -p "¿Continuar con el despliegue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Despliegue cancelado por el usuario"
    exit 0
fi

# Inicializar Terraform
log "Inicializando Terraform..."
terraform init

# Validar configuración
log "Validando configuración..."
terraform validate

# Crear plan
log "Creando plan de despliegue..."
terraform plan -out=poc-5h.tfplan

# Mostrar resumen del plan
log "Resumen del plan creado. Aplicando configuración..."

# Aplicar configuración
log "🚀 Iniciando despliegue de infraestructura..."
START_TIME=$(date +%s)

if terraform apply poc-5h.tfplan; then
    END_TIME=$(date +%s)
    DEPLOY_TIME=$((END_TIME - START_TIME))
    
    log "✅ Despliegue completado en ${DEPLOY_TIME} segundos"
    
    # Mostrar outputs importantes
    echo -e "${BLUE}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    DESPLIEGUE EXITOSO                        "
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    log "📊 Outputs importantes:"
    terraform output
    
    # Programar auto-destrucción
    if [ "$AUTO_DESTROY" = true ]; then
        DESTROY_TIME=$(date -d '+5 hours' +'%Y-%m-%d %H:%M:%S')
        log "⏰ Programando auto-destrucción para: $DESTROY_TIME"
        
        # Crear script de destrucción
        DESTROY_SCRIPT="/tmp/destroy-poc-$(date +%s).sh"
        cat > "$DESTROY_SCRIPT" << EOF
#!/bin/bash
cd "$POC_DIR"
echo "🚨 Auto-destruyendo infraestructura POC..."
terraform destroy -auto-approve
echo "✅ Infraestructura POC destruida automáticamente"
rm -f "$DESTROY_SCRIPT"
EOF
        chmod +x "$DESTROY_SCRIPT"
        
        # Programar ejecución
        echo "$DESTROY_SCRIPT" | at now + 5 hours 2>/dev/null || {
            warn "No se pudo programar auto-destrucción automática"
            echo "Ejecuta manualmente en 5 horas: terraform destroy"
        }
    else
        warn "Auto-destrucción no disponible. Recuerda ejecutar 'terraform destroy' en 5 horas"
    fi
    
    # Instrucciones post-despliegue
    echo -e "${GREEN}"
    echo "🎯 PRÓXIMOS PASOS:"
    echo "1. Configurar kubectl:"
    echo "   aws eks update-kubeconfig --region us-east-1 --name poc-cluster"
    echo ""
    echo "2. Verificar Pinot:"
    echo "   kubectl get pods -n pinot"
    echo "   kubectl port-forward -n pinot svc/pinot-controller 9000:9000"
    echo ""
    echo "3. Acceder a Pinot UI:"
    echo "   http://localhost:9000"
    echo ""
    echo "4. Obtener Kafka endpoints:"
    echo "   terraform output kafka_bootstrap_brokers"
    echo -e "${NC}"
    
    # Información de costos
    echo -e "${YELLOW}"
    echo "💰 INFORMACIÓN DE COSTOS:"
    echo "   - Costo por hora: ~\$0.40 USD"
    echo "   - Costo 5 horas: ~\$2.00 USD"
    echo "   - Auto-destrucción: $(if [ "$AUTO_DESTROY" = true ]; then echo "$DESTROY_TIME"; else echo "Manual"; fi)"
    echo -e "${NC}"
    
    # Cleanup del plan
    rm -f poc-5h.tfplan
    
else
    error "❌ Falló el despliegue de infraestructura"
    exit 1
fi

log "🎉 Script completado exitosamente!"
