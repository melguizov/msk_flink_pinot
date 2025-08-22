# Development Environment - Enhanced Resources

Este ambiente está optimizado para **desarrollo activo** con recursos balanceados que proporcionan mejor rendimiento que el POC manteniendo costos razonables.

## 💰 Estimación de Costos (Mensual)

### Desglose por Servicio:

| Servicio | Configuración | Costo Estimado |
|----------|---------------|----------------|
| **Amazon MSK** | 3 × kafka.m5.large + 300GB EBS | ~$180/mes |
| **Kinesis Analytics (Flink)** | 1-2 KPU | ~$110-220/mes |
| **Amazon EKS** | Control plane + 2 × t3.medium | ~$125/mes |
| **VPC/Networking** | 2 NAT Gateways + EIPs | ~$70/mes |
| **Load Balancer** | 1 ALB + target groups | ~$25/mes |
| **Storage** | EBS enhanced + logs | ~$40/mes |

### **Total Estimado: ~$580/mes (~$6,960/año)**

> ✅ **Ideal para**: Desarrollo activo, testing de performance, datasets medianos

## 🏗️ Arquitectura Development

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Multi-AZ      │    │      MSK        │    │      EKS        │
│   VPC Setup     │───▶│   3 Brokers     │───▶│   2 Nodes       │
│   us-east-1a/b  │    │   m5.large      │    │   t3.medium     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                       ┌─────────────────┐            │
                       │     Flink       │◀───────────┘
                       │   1-2 KPU       │
                       └─────────────────┘
                                │
                       ┌─────────────────┐
                       │     Pinot       │
                       │ Controller: 2   │
                       │ Broker: 2       │
                       │ Server: 2       │
                       │ Minion: 1       │
                       │ Zookeeper: 3    │
                       └─────────────────┘
```

## 🚀 Mejoras vs POC

### ✅ **Capacidades Mejoradas:**

| Aspecto | POC | Development | Mejora |
|---------|-----|-------------|--------|
| **Throughput** | ~1K msg/sec | ~10K msg/sec | **10x** |
| **Storage** | ~15GB total | ~300GB total | **20x** |
| **Availability** | Single AZ | Multi-AZ | **HA** |
| **Query Performance** | 1 broker | 2 brokers | **2x** |
| **Data Retention** | 1-7 días | 30-90 días | **10x** |
| **Concurrent Users** | 1-2 | 5-10 | **5x** |

### 🔧 **Configuraciones Clave:**

#### **MSK (Kafka):**
- **Instancias**: 3 × kafka.m5.large (vs 2 × t3.small)
- **Storage**: 100GB por broker (vs 10GB)
- **Multi-AZ**: Distribución en 2 AZs
- **Throughput**: ~10K mensajes/segundo

#### **EKS (Kubernetes):**
- **Nodos**: 2 × t3.medium (vs 1 × t3.small)
- **Auto-scaling**: 2-4 nodos según demanda
- **Storage**: 50GB por nodo (vs 10GB)
- **Multi-AZ**: Nodos distribuidos

#### **Pinot (Analytics):**
- **Controllers**: 2 replicas (HA)
- **Brokers**: 2 replicas (mejor query performance)
- **Servers**: 2 replicas (distribución de datos)
- **Zookeeper**: 3 nodos (ensemble confiable)
- **Storage**: 100GB para datos (vs 5GB)

## 🚀 Despliegue Development

### 1. Preparación

```bash
cd /Users/daniel.melguizo/Documents/repositories/msk_flink_pinot/terraform/envs/dev

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
terraform plan -out=dev.tfplan
```

### 3. Despliegue

```bash
# Aplicar la configuración
terraform apply dev.tfplan

# Tiempo estimado de despliegue: 15-20 minutos
```

### 4. Verificación Post-Despliegue

```bash
# Ver outputs importantes
terraform output

# Configurar kubectl
aws eks update-kubeconfig --region us-east-1 --name dev-pinot-cluster

# Verificar nodos EKS
kubectl get nodes

# Verificar pods de Pinot
kubectl get pods -n pinot-dev

# Verificar MSK cluster
aws kafka describe-cluster --cluster-arn $(terraform output -raw kafka_cluster_arn)
```

## 🔧 Configuración Post-Despliegue

### Acceder a Pinot Controller

```bash
# Port forward para acceder a Pinot Controller
kubectl port-forward -n pinot-dev svc/pinot-controller 9000:9000

# Abrir en navegador: http://localhost:9000
```

### Configurar Kafka Topics

```bash
# Obtener bootstrap servers
BOOTSTRAP_SERVERS=$(terraform output -raw kafka_bootstrap_brokers)

# Crear topics para desarrollo
kafka-topics.sh --create --topic events --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 6 --replication-factor 3

kafka-topics.sh --create --topic metrics --bootstrap-server $BOOTSTRAP_SERVERS \
  --partitions 3 --replication-factor 3
```

### Configurar Pinot Tables

```bash
# Ejemplo de tabla para eventos
cat > events_table.json << EOF
{
  "tableName": "events",
  "tableType": "REALTIME",
  "segmentsConfig": {
    "timeColumnName": "timestamp",
    "timeType": "MILLISECONDS",
    "retentionTimeUnit": "DAYS",
    "retentionTimeValue": "30"
  },
  "tenants": {},
  "tableIndexConfig": {
    "loadMode": "MMAP",
    "streamConfigs": {
      "streamType": "kafka",
      "stream.kafka.consumer.type": "lowlevel",
      "stream.kafka.topic.name": "events",
      "stream.kafka.decoder.class.name": "org.apache.pinot.plugin.stream.kafka.KafkaJSONMessageDecoder",
      "stream.kafka.consumer.factory.class.name": "org.apache.pinot.plugin.stream.kafka20.KafkaConsumerFactory",
      "stream.kafka.broker.list": "$BOOTSTRAP_SERVERS",
      "realtime.segment.flush.threshold.rows": "1000000",
      "realtime.segment.flush.threshold.time": "3600000"
    }
  },
  "metadata": {
    "customConfigs": {}
  }
}
EOF

# Crear tabla en Pinot
curl -X POST "http://localhost:9000/tables" \
  -H "Content-Type: application/json" \
  -d @events_table.json
```

## 📊 Monitoreo y Observabilidad

### CloudWatch Dashboards

```bash
# Crear dashboard personalizado para development
aws cloudwatch put-dashboard --dashboard-name "MSK-Flink-Pinot-Dev" --dashboard-body '{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/MSK", "BytesInPerSec", "Cluster Name", "dev-msk-cluster"],
          [".", "BytesOutPerSec", ".", "."]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "MSK Throughput"
      }
    }
  ]
}'
```

### Logs Centralizados

```bash
# Configurar log forwarding desde EKS
kubectl apply -f - << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: amazon-cloudwatch
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    [INPUT]
        Name              tail
        Tag               pinot.*
        Path              /var/log/containers/pinot*.log
        Parser            docker
        DB                /var/log/flb_pinot.db
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [OUTPUT]
        Name                cloudwatch_logs
        Match               pinot.*
        region              us-east-1
        log_group_name      /aws/eks/dev-pinot-cluster/pinot
        log_stream_prefix   dev-
        auto_create_group   true
EOF
```

## 🔄 Workflows de Desarrollo

### 1. **Desarrollo de Schemas**

```bash
# Directorio para schemas
mkdir -p schemas/

# Ejemplo de schema para eventos
cat > schemas/events_schema.json << EOF
{
  "schemaName": "events",
  "dimensionFieldSpecs": [
    {"name": "userId", "dataType": "STRING"},
    {"name": "eventType", "dataType": "STRING"},
    {"name": "platform", "dataType": "STRING"}
  ],
  "metricFieldSpecs": [
    {"name": "duration", "dataType": "LONG"},
    {"name": "count", "dataType": "INT"}
  ],
  "dateTimeFieldSpecs": [
    {"name": "timestamp", "dataType": "LONG", "format": "1:MILLISECONDS:EPOCH", "granularity": "1:MILLISECONDS"}
  ]
}
EOF
```

### 2. **Testing de Performance**

```bash
# Script de carga de datos de prueba
cat > load_test_data.py << EOF
import json
import time
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers=['$BOOTSTRAP_SERVERS'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

# Generar datos de prueba
for i in range(10000):
    event = {
        'userId': f'user_{i % 1000}',
        'eventType': 'click',
        'platform': 'web',
        'timestamp': int(time.time() * 1000),
        'duration': 150 + (i % 300),
        'count': 1
    }
    producer.send('events', event)
    
    if i % 1000 == 0:
        print(f'Sent {i} events')

producer.flush()
print('Load test completed')
EOF

python3 load_test_data.py
```

### 3. **Queries de Desarrollo**

```sql
-- Queries típicas para desarrollo
SELECT 
    eventType,
    COUNT(*) as event_count,
    AVG(duration) as avg_duration
FROM events 
WHERE timestamp > ago('1h')
GROUP BY eventType
ORDER BY event_count DESC;

-- Query de performance con filtros
SELECT 
    platform,
    eventType,
    COUNT(*) as events,
    PERCENTILE_TDIGEST(duration, 95) as p95_duration
FROM events 
WHERE timestamp BETWEEN ago('24h') AND now()
  AND userId IN ('user_1', 'user_2', 'user_3')
GROUP BY platform, eventType;
```

## 💡 Optimizaciones de Desarrollo

### 1. **Spot Instances para Ahorro**

```hcl
# En main.tf, agregar para nodos EKS:
capacity_type = "SPOT"
# Ahorro potencial: 50-70%
```

### 2. **Scheduled Scaling**

```bash
# Script para escalar durante horarios de desarrollo
cat > scale_dev_cluster.sh << EOF
#!/bin/bash
HOUR=$(date +%H)

if [ $HOUR -ge 9 ] && [ $HOUR -le 18 ]; then
    # Horario laboral: escalar a 2-4 nodos
    aws eks update-nodegroup-config \
        --cluster-name dev-pinot-cluster \
        --nodegroup-name dev-nodes \
        --scaling-config minSize=2,maxSize=4,desiredSize=2
else
    # Fuera de horario: escalar a 1 nodo
    aws eks update-nodegroup-config \
        --cluster-name dev-pinot-cluster \
        --nodegroup-name dev-nodes \
        --scaling-config minSize=1,maxSize=2,desiredSize=1
fi
EOF

# Programar con cron
# 0 9,18 * * 1-5 /path/to/scale_dev_cluster.sh
```

### 3. **Backup Automático**

```bash
# Script de backup para desarrollo
cat > backup_dev_data.sh << EOF
#!/bin/bash
DATE=$(date +%Y%m%d)
S3_BUCKET="your-dev-backups-bucket"

# Backup de configuraciones Pinot
kubectl get configmaps -n pinot-dev -o yaml > pinot-configs-$DATE.yaml
aws s3 cp pinot-configs-$DATE.yaml s3://$S3_BUCKET/configs/

# Backup de schemas
curl -X GET "http://localhost:9000/schemas" > schemas-$DATE.json
aws s3 cp schemas-$DATE.json s3://$S3_BUCKET/schemas/

echo "Backup completed for $DATE"
EOF
```

## 🚨 Limitaciones del Ambiente Development

### ⚠️ **Consideraciones**:

- **No es para producción**: Configuración optimizada para desarrollo
- **Datos temporales**: Retención de 30-90 días
- **Monitoreo básico**: CloudWatch estándar
- **Backup manual**: No hay backup automático configurado
- **Seguridad básica**: Security groups y IAM básicos

## 🔄 Upgrade Path a Staging/Producción

### Para escalar a staging:

1. **Aumentar instancias**:
   ```hcl
   kafka_instance_type = "kafka.m5.xlarge"
   eks_node_instance_types = ["t3.large"]
   ```

2. **Multi-región**:
   ```hcl
   # Configurar cross-region replication
   ```

3. **Enhanced monitoring**:
   - Prometheus + Grafana
   - Custom metrics
   - Alerting rules

4. **Backup automático**:
   - S3 lifecycle policies
   - Cross-region backup
   - Point-in-time recovery

## 🧹 Cleanup

```bash
# Destruir ambiente development
terraform destroy

# Confirmar destrucción
# IMPORTANTE: Esto eliminará TODOS los recursos y datos
```

---

**🎯 Objetivo Development**: Ambiente robusto para desarrollo activo con balance entre performance y costo.

**💰 Costo por Duración:**

| Duración | Costo Total | Ideal Para |
|----------|-------------|------------|
| **8 horas** | **~$3.50** | Día de desarrollo |
| **40 horas** | **~$17.50** | Semana de desarrollo |
| **160 horas** | **~$70** | Sprint mensual |
| **1 mes** | **~$580** | Desarrollo continuo |
