# POC Environment - Minimal Cost Configuration

Este ambiente está optimizado para **Proof of Concept (POC)** con el menor costo posible manteniendo la funcionalidad básica de la infraestructura.

## 💰 Estimación de Costos (Mensual)

### Desglose por Servicio:

| Servicio | Configuración | Costo Estimado |
|----------|---------------|----------------|
| **Amazon MSK** | 2 × kafka.t3.small + 20GB EBS | ~$58/mes |
| **Kinesis Analytics (Flink)** | 1 KPU mínimo | ~$110/mes |
| **Amazon EKS** | Control plane + 1 × t3.small | ~$88/mes |
| **VPC/Networking** | 1 NAT Gateway + EIP | ~$35/mes |
| **Load Balancer** | 1 ALB básico | ~$23/mes |
| **Storage** | EBS + logs mínimos | ~$10/mes |
| **Pinot Minion** | 1 replica (256Mi RAM) | ~$10/mes |

### **Total Estimado: ~$334/mes (~$4,008/año)**

> ⚠️ **Nota**: Esta configuración NO es para producción. Es únicamente para POC/testing.

## 🏗️ Arquitectura POC

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Single AZ     │    │      MSK        │    │      EKS        │
│   VPC Setup     │───▶│   2 Brokers     │───▶│   1 Node        │
│                 │    │   t3.small      │    │   t3.small      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌─────────────────┐            │
                       │     Flink       │◀───────────┘
                       │   1 KPU Min     │
                       └─────────────────┘
                                │
                       ┌─────────────────┐
                       │     Pinot       │
                       │ Controller: 1   │
                       │ Broker: 1       │
                       │ Server: 1       │
                       │ Minion: 1       │
                       │ Zookeeper: 1    │
                       └─────────────────┘
```

## 🚀 Despliegue Rápido

### 1. Preparación

```bash
cd /Users/daniel.melguizo/Documents/repositories/msk_flink_pinot/terraform/envs/poc

# Inicializar Terraform
terraform init

# Validar configuración
terraform validate
```

### 2. Planificación

```bash
# Ver qué recursos se van a crear
terraform plan

# Guardar el plan para revisión
terraform plan -out=poc.tfplan
```

### 3. Despliegue

```bash
# Aplicar la configuración
terraform apply poc.tfplan

# O aplicar directamente (requiere confirmación)
terraform apply
```

### 4. Verificación

```bash
# Ver outputs importantes
terraform output

# Verificar EKS cluster
aws eks describe-cluster --name poc-cluster --region us-east-1

# Verificar MSK cluster
aws kafka describe-cluster --cluster-arn $(terraform output -raw kafka_cluster_arn)
```

## 🔧 Configuración Post-Despliegue

### Conectar a EKS

```bash
# Configurar kubectl
aws eks update-kubeconfig --region us-east-1 --name poc-cluster

# Verificar nodos
kubectl get nodes

# Verificar pods de Pinot
kubectl get pods -n pinot
```

### Acceder a Pinot

```bash
# Port forward para acceder a Pinot Controller
kubectl port-forward -n pinot svc/pinot-controller 9000:9000

# Abrir en navegador: http://localhost:9000
```

### Verificar Kafka

```bash
# Obtener bootstrap servers
BOOTSTRAP_SERVERS=$(terraform output -raw kafka_bootstrap_brokers)
echo $BOOTSTRAP_SERVERS

# Crear un topic de prueba (desde una instancia EC2 o container)
kafka-topics.sh --create --topic test-topic --bootstrap-server $BOOTSTRAP_SERVERS --partitions 1 --replication-factor 2
```

## ⚡ Optimizaciones de Costo Implementadas

### ✅ Configuraciones Aplicadas:

1. **Single AZ Deployment**: Elimina costos de transferencia entre AZs
2. **Minimal Instance Types**: t3.small para EKS, kafka.t3.small para MSK
3. **Reduced Storage**: 2-5GB por componente vs 20-50GB estándar
4. **Single Replicas**: 1 replica por componente de Pinot (incluyendo Minion)
5. **Essential Components**: Todos los componentes necesarios habilitados
6. **Minimal Resources**: CPU/Memory requests muy bajos

### 🔍 **¿Por qué necesitamos Pinot Minion?**

El **Pinot Minion** es esencial para:

1. **Segment Management**: Compactación y merge de segmentos
2. **Data Purging**: Eliminación de datos expirados
3. **Index Building**: Construcción de índices offline
4. **Data Conversion**: Transformación de formatos de datos
5. **Cleanup Tasks**: Limpieza de archivos temporales

> ⚠️ **Sin Minion**: Pinot puede funcionar pero tendrás problemas de:
> - Acumulación de segmentos pequeños
> - Degradación del performance
> - Uso excesivo de storage
> - Falta de mantenimiento automático

### 💡 Optimizaciones Adicionales Posibles:

1. **Usar Spot Instances** para EKS (ahorro 50-70%):
   ```hcl
   capacity_type = "SPOT"
   ```

2. **Scheduled Shutdown** (para desarrollo):
   ```bash
   # Script para apagar recursos fuera de horario laboral
   # Puede reducir costos hasta 60%
   ```

3. **S3 Backend Optimizado**:
   ```hcl
   backend "s3" {
     bucket = "terraform-state-poc"
     key    = "poc/terraform.tfstate"
     region = "us-east-1"
     # Usar S3 Standard-IA para state files
   }
   ```

## 💰 Costo por Duración

| Duración | Costo Total | Ideal Para |
|----------|-------------|------------|
| **5 horas** | **~$2.00** | Demos, workshops |
| **8 horas** | ~$3.20 | Día de desarrollo |
| **24 horas** | ~$9.60 | Testing intensivo |
| **1 semana** | ~$67.20 | Sprint de desarrollo |
| **1 mes** | ~$334.00 | POC completo |

## 🚨 Limitaciones del POC

### ⚠️ **NO usar en producción**:

- **Sin Alta Disponibilidad**: Single AZ, single node
- **Sin Backup**: No hay estrategia de backup configurada
- **Recursos Limitados**: Puede tener problemas con cargas altas
- **Sin Monitoreo**: Configuración mínima de CloudWatch
- **Sin Seguridad Avanzada**: Configuración básica de security groups

### 📊 **Capacidades Limitadas**:

- **Throughput**: ~1000 mensajes/segundo
- **Storage**: ~10GB de datos históricos
- **Concurrent Users**: 1-2 usuarios simultáneos
- **Data Retention**: 1-7 días máximo
- **Segment Management**: Básico con 1 Minion

## 🔄 Upgrade Path

### Para escalar a staging/producción:

1. **Multi-AZ Deployment**:
   ```hcl
   vpc_azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
   ```

2. **Larger Instances**:
   ```hcl
   kafka_instance_type = "kafka.m5.large"
   eks_node_instance_types = ["t3.medium"]
   ```

3. **High Availability**:
   ```hcl
   pinot_zookeeper_replicas = 3
   pinot_server_replicas = 2
   ```

4. **Enhanced Monitoring**:
   - CloudWatch dashboards
   - Prometheus + Grafana
   - Alerting rules

## 🧹 Cleanup

```bash
# Destruir toda la infraestructura
terraform destroy

# Confirmar destrucción
# IMPORTANTE: Esto eliminará TODOS los recursos y datos
```

## 📞 Soporte

Para problemas o preguntas sobre este POC:

1. Revisar logs de Terraform: `terraform show`
2. Verificar recursos en AWS Console
3. Consultar documentación de cada servicio
4. Contactar al equipo de datos para escalamiento

---

**🎯 Objetivo del POC**: Validar la integración Kafka → Flink → Pinot con el menor costo posible.

## 🚀 Script de Auto-Destrucción (5 horas)

```bash
#!/bin/bash
# deploy-5h-poc.sh

echo "🚀 Iniciando despliegue POC de 5 horas..."
echo "💰 Costo estimado: $2.00 USD"

cd terraform/envs/poc

# Desplegar
terraform init
terraform apply -auto-approve

# Programar destrucción automática en 5 horas
echo "⏰ Programando destrucción automática en 5 horas..."
echo "cd $(pwd) && terraform destroy -auto-approve" | at now + 5 hours

echo "✅ Despliegue completado!"
echo "🔗 Endpoints disponibles en: terraform output"
echo "⚠️  Auto-destrucción programada para: $(date -d '+5 hours')"
```
