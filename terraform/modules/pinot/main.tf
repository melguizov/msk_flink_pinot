resource "helm_release" "zookeeper" {
  count      = var.enable_pinot_deployment ? 1 : 0
  name       = var.zookeeper_release_name
  repository = var.zookeeper_helm_repo
  chart      = var.zookeeper_helm_chart
  version    = var.zookeeper_helm_version
  namespace  = var.namespace

  values = [
    yamlencode({
      replicaCount = var.zookeeper_replicas
      persistence = {
        enabled = true
        size    = var.zookeeper_storage_size
      }
      resources = var.zookeeper_resources
      service = {
        type = "ClusterIP"
      }
    })
  ]
}

resource "helm_release" "pinot" {
  count      = var.enable_pinot_deployment ? 1 : 0
  name       = var.pinot_release_name
  repository = var.pinot_helm_repo
  chart      = var.pinot_helm_chart
  version    = var.pinot_helm_version
  namespace  = var.namespace

  values = [
    yamlencode({
      controller = {
        replicaCount = var.pinot_controller_replicas
        resources    = var.pinot_controller_resources
        persistence = {
          enabled = true
          size    = var.pinot_controller_storage_size
        }
        service = {
          type = "ClusterIP"
        }
      }
      broker = {
        replicaCount = var.pinot_broker_replicas
        resources    = var.pinot_broker_resources
        persistence = {
          enabled = true
          size    = var.pinot_broker_storage_size
        }
        service = {
          type = "ClusterIP"
        }
      }
      server = {
        replicaCount = var.pinot_server_replicas
        resources    = var.pinot_server_resources
        persistence = {
          enabled = true
          size    = var.pinot_server_storage_size
        }
        service = {
          type = "ClusterIP"
        }
      }
      minion = {
        replicaCount = var.pinot_minion_replicas
        resources    = var.pinot_minion_resources
        persistence = {
          enabled = true
          size    = var.pinot_minion_storage_size
        }
      }
      zookeeper = {
        enabled = false # Usamos el chart externo
        url     = var.enable_pinot_deployment ? join(",", [for i in range(var.zookeeper_replicas) : "${helm_release.zookeeper[0].name}-zookeeper-${i}.${helm_release.zookeeper[0].name}-zookeeper-headless.${var.namespace}.svc.cluster.local:2181"]) : ""
      }
    })
  ]
  depends_on = [helm_release.zookeeper]
}
