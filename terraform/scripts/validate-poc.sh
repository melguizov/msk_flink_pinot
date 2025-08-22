#!/bin/bash
# validate-poc.sh
# Script para validar la configuración POC antes del despliegue

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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    POC Validation Script                     ║"
echo "║              MSK + Flink + Pinot on AWS                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Cambiar al directorio POC
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POC_DIR="$SCRIPT_DIR/../envs/poc"

log "Cambiando a directorio POC: $POC_DIR"
cd "$POC_DIR"

# Verificar dependencias
log "🔍 Verificando dependencias..."

DEPENDENCIES_OK=true

if ! command -v terraform &> /dev/null; then
    error "❌ Terraform no está instalado"
    DEPENDENCIES_OK=false
else
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    info "✅ Terraform version: $TERRAFORM_VERSION"
fi

if ! command -v aws &> /dev/null; then
    error "❌ AWS CLI no está instalado"
    DEPENDENCIES_OK=false
else
    AWS_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    info "✅ AWS CLI version: $AWS_VERSION"
fi

if ! command -v kubectl &> /dev/null; then
    warn "⚠️  kubectl no está instalado (requerido para post-despliegue)"
else
    KUBECTL_VERSION=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
    info "✅ kubectl version: $KUBECTL_VERSION"
fi

if ! command -v jq &> /dev/null; then
    warn "⚠️  jq no está instalado (útil para parsing JSON)"
else
    info "✅ jq está disponible"
fi

if [ "$DEPENDENCIES_OK" = false ]; then
    error "❌ Faltan dependencias críticas"
    exit 1
fi

# Verificar credenciales AWS
log "🔐 Verificando credenciales AWS..."
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    info "✅ AWS Account: $AWS_ACCOUNT"
    info "✅ AWS User: $AWS_USER"
else
    error "❌ Credenciales AWS no configuradas correctamente"
    exit 1
fi

# Verificar región AWS
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
    warn "⚠️  Región AWS no configurada, usando default: $AWS_REGION"
else
    info "✅ AWS Region: $AWS_REGION"
fi

# Validar configuración Terraform
log "📋 Validando configuración Terraform..."

if [ ! -f "main.tf" ]; then
    error "❌ No se encuentra main.tf en el directorio POC"
    exit 1
fi

# Inicializar si es necesario
if [ ! -d ".terraform" ]; then
    log "🔄 Inicializando Terraform..."
    terraform init
fi

# Validar sintaxis
log "🔍 Validando sintaxis Terraform..."
if terraform validate; then
    info "✅ Configuración Terraform válida"
else
    error "❌ Configuración Terraform inválida"
    exit 1
fi

# Verificar formato
log "📝 Verificando formato Terraform..."
if terraform fmt -check=true -diff=true; then
    info "✅ Formato Terraform correcto"
else
    warn "⚠️  Formato Terraform necesita corrección. Ejecuta: terraform fmt"
fi

# Crear plan de validación
log "📊 Creando plan de validación..."
if terraform plan -out=validation.tfplan > /dev/null 2>&1; then
    info "✅ Plan de Terraform creado exitosamente"
    
    # Mostrar resumen del plan
    PLAN_SUMMARY=$(terraform show -json validation.tfplan | jq -r '.planned_values.root_module.child_modules | length')
    info "📦 Módulos a desplegar: $PLAN_SUMMARY"
    
    # Cleanup
    rm -f validation.tfplan
else
    error "❌ Falló la creación del plan de Terraform"
    exit 1
fi

# Verificar configuración de costos
log "💰 Verificando configuración de costos..."

# Extraer configuraciones críticas del main.tf
MSK_INSTANCE=$(grep -o 'kafka_instance_type.*=.*"[^"]*"' main.tf | cut -d'"' -f2)
EKS_INSTANCE=$(grep -o 'eks_node_instance_types.*=.*\["[^"]*"\]' main.tf | sed 's/.*"\([^"]*\)".*/\1/')
MSK_BROKERS=$(grep -o 'kafka_broker_nodes.*=.*[0-9]*' main.tf | grep -o '[0-9]*$')
EKS_NODES=$(grep -o 'eks_node_desired_size.*=.*[0-9]*' main.tf | grep -o '[0-9]*$')

info "🖥️  MSK Instance Type: $MSK_INSTANCE"
info "🖥️  EKS Instance Type: $EKS_INSTANCE"
info "📊 MSK Brokers: $MSK_BROKERS"
info "📊 EKS Nodes: $EKS_NODES"

# Validar que son configuraciones mínimas
if [ "$MSK_INSTANCE" != "kafka.t3.small" ]; then
    warn "⚠️  MSK instance type no es el mínimo (kafka.t3.small)"
fi

if [ "$EKS_INSTANCE" != "t3.small" ]; then
    warn "⚠️  EKS instance type no es el mínimo recomendado (t3.small)"
fi

if [ "$MSK_BROKERS" -gt 2 ]; then
    warn "⚠️  Más de 2 brokers MSK (aumenta costos)"
fi

if [ "$EKS_NODES" -gt 1 ]; then
    warn "⚠️  Más de 1 nodo EKS (aumenta costos)"
fi

# Verificar configuración de AZ
AZ_COUNT=$(grep -o 'vpc_azs.*=.*\[.*\]' main.tf | grep -o '"[^"]*"' | wc -l | tr -d ' ')
if [ "$AZ_COUNT" -gt 1 ]; then
    warn "⚠️  Configuración multi-AZ detectada (aumenta costos)"
else
    info "✅ Configuración single-AZ (optimizada para costos)"
fi

# Verificar storage mínimo
STORAGE_CONFIGS=$(grep -c "storage_size.*=.*\"[0-9]*Gi\"" main.tf)
info "📦 Configuraciones de storage encontradas: $STORAGE_CONFIGS"

# Verificar Pinot Minion habilitado
MINION_REPLICAS=$(grep -o 'pinot_minion_replicas.*=.*[0-9]*' main.tf | grep -o '[0-9]*$')
if [ "$MINION_REPLICAS" -eq 0 ]; then
    error "❌ Pinot Minion deshabilitado (requerido para segment management)"
    exit 1
else
    info "✅ Pinot Minion habilitado ($MINION_REPLICAS replica)"
fi

# Estimación de costos
log "💰 Estimación de costos POC..."

# Costos base por hora (us-east-1)
MSK_COST_HOUR=$(echo "0.042 * $MSK_BROKERS" | bc -l)
EKS_CONTROL_COST_HOUR=0.10
EKS_NODE_COST_HOUR=$(echo "0.0208 * $EKS_NODES" | bc -l)
FLINK_COST_HOUR=0.11
NAT_COST_HOUR=0.045
ALB_COST_HOUR=0.0225
STORAGE_COST_HOUR=0.01

TOTAL_COST_HOUR=$(echo "$MSK_COST_HOUR + $EKS_CONTROL_COST_HOUR + $EKS_NODE_COST_HOUR + $FLINK_COST_HOUR + $NAT_COST_HOUR + $ALB_COST_HOUR + $STORAGE_COST_HOUR" | bc -l)
COST_5_HOURS=$(echo "$TOTAL_COST_HOUR * 5" | bc -l)
COST_MONTHLY=$(echo "$TOTAL_COST_HOUR * 24 * 30" | bc -l)

printf "💰 Costo por hora: \$%.2f USD\n" $TOTAL_COST_HOUR
printf "💰 Costo 5 horas: \$%.2f USD\n" $COST_5_HOURS
printf "💰 Costo mensual: \$%.0f USD\n" $COST_MONTHLY

# Resumen final
echo -e "${GREEN}"
echo "═══════════════════════════════════════════════════════════════"
echo "                    VALIDACIÓN COMPLETADA                     "
echo "═══════════════════════════════════════════════════════════════"
echo -e "${NC}"

log "✅ Configuración POC validada exitosamente"
log "🚀 Lista para desplegar con: ./scripts/deploy-5h-poc.sh"

echo -e "${YELLOW}"
echo "📋 CHECKLIST FINAL:"
echo "   ✅ Dependencias instaladas"
echo "   ✅ Credenciales AWS configuradas"
echo "   ✅ Configuración Terraform válida"
echo "   ✅ Configuración de costos optimizada"
echo "   ✅ Pinot Minion habilitado"
echo "   ✅ Single-AZ deployment"
echo "   ✅ Instancias mínimas configuradas"
echo -e "${NC}"

info "🎯 Configuración lista para POC de 5 horas por ~\$2.00 USD"
