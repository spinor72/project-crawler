variable project {
  description = "Project ID"
}

variable zone {
  description = "Zone"
}

variable cluster_name {
  description = "Cluster name"
  default     = "kubernetes-cluster"
}

variable kubernetes_version {
  description = "Kubernetes version"
  default     = "1.8.10-gke.0"
}

variable machine_type {
  description = "The name of a Google Compute Engine machine type"
  default     = "g1-small"
}

variable disk_size_gb {
  description = "Size of the disk attached to each node, specified in GB. The smallest allowed disk size is 10GB"
  default     = 20
}

variable node_count {
  description = "The number of nodes to create in this cluster (not including the Kubernetes master)"
  default     = 2
}

variable big_node_count {
  description = "The number of big nodes to create in this cluster (not including the Kubernetes master)"
  default     = 2
}

variable disable_dashboard {
  description = "Disable Kubernetes dasboard"
  default     = false
}

variable disable_networkpolicy {
  description = "Disable Kubernetes NetworkPolicy"
  default     = false
}

variable enable_legacy_abac {
  description = "Enable legacy ABAC"
  default     = false
}
