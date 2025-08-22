# Kubernetes resources for Flink (conditional based on cluster availability)

# Kubernetes namespace for Flink
resource "kubernetes_namespace" "flink" {
  count = var.enable_kubernetes_resources ? 1 : 0
  
  metadata {
    name = "flink"
  }
}

resource "kubernetes_config_map" "flink_config" {
  count = var.enable_kubernetes_resources ? 1 : 0
  
  metadata {
    name      = "flink-config"
    namespace = kubernetes_namespace.flink[0].metadata[0].name
  }
  data = var.flink_properties
}

resource "kubernetes_service_account" "flink" {
  count = var.enable_kubernetes_resources ? 1 : 0
  
  metadata {
    name      = "flink-sa"
    namespace = kubernetes_namespace.flink[0].metadata[0].name
  }
}

resource "kubernetes_role" "flink" {
  count = var.enable_kubernetes_resources ? 1 : 0
  
  metadata {
    name      = "flink-role"
    namespace = kubernetes_namespace.flink[0].metadata[0].name
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "flink" {
  count = var.enable_kubernetes_resources ? 1 : 0
  
  metadata {
    name      = "flink-rolebinding"
    namespace = kubernetes_namespace.flink[0].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.flink[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.flink[0].metadata[0].name
    namespace = kubernetes_namespace.flink[0].metadata[0].name
  }
}

resource "kubernetes_deployment" "jobmanager" {
  count = var.enable_kubernetes_resources ? 1 : 0
  
  metadata {
    name      = "flink-jobmanager"
    namespace = kubernetes_namespace.flink[0].metadata[0].name
  }
  spec {
    replicas = var.jobmanager_replicas
    selector {
      match_labels = {
        app = "flink"
        component = "jobmanager"
      }
    }
    template {
      metadata {
        labels = {
          app = "flink"
          component = "jobmanager"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.flink[0].metadata[0].name
        container {
          name  = "jobmanager"
          image = var.flink_image
          port {
            container_port = 8081
          }
          env_from {
            config_map_ref {
              name = kubernetes_config_map.flink_config[0].metadata[0].name
            }
          }
          resources {
            limits = var.jobmanager_resources_limits
            requests = var.jobmanager_resources_requests
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "jobmanager" {
  count = var.enable_kubernetes_resources ? 1 : 0
  
  metadata {
    name      = "flink-jobmanager"
    namespace = kubernetes_namespace.flink[0].metadata[0].name
    labels = {
      app = "flink"
      component = "jobmanager"
    }
  }
  spec {
    selector = {
      app = "flink"
      component = "jobmanager"
    }
    port {
      port        = 8081
      target_port = 8081
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "taskmanager" {
  count = var.enable_kubernetes_resources ? 1 : 0
  
  metadata {
    name      = "flink-taskmanager"
    namespace = kubernetes_namespace.flink[0].metadata[0].name
    labels = {
      app = "flink"
      component = "taskmanager"
    }
  }
  spec {
    replicas = var.taskmanager_replicas
    selector {
      match_labels = {
        app = "flink"
        component = "taskmanager"
      }
    }
    template {
      metadata {
        labels = {
          app = "flink"
          component = "taskmanager"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.flink[0].metadata[0].name
        container {
          name  = "taskmanager"
          image = var.flink_image
          port {
            container_port = 6121
          }
          env_from {
            config_map_ref {
              name = kubernetes_config_map.flink_config[0].metadata[0].name
            }
          }
          resources {
            limits = var.taskmanager_resources_limits
            requests = var.taskmanager_resources_requests
          }
        }
      }
    }
  }
}
