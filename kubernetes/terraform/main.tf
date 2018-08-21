resource "google_container_cluster" "cluster" {
  name               = "${var.cluster_name}"
  project            = "${var.project}"
  zone               = "${var.zone}"
  initial_node_count = "${var.node_count}"

  min_master_version = "${var.kubernetes_version}"
  node_version       = "${var.kubernetes_version}"
  enable_legacy_abac = true
  logging_service    = "none"
  monitoring_service = "none"

  # enable_legacy_abac = false not supported by gitlab omnibus

  master_auth {
    username = ""
    password = ""
  }
  addons_config {
    kubernetes_dashboard {
      disabled = "${var.disable_dashboard}"
    }

    network_policy_config {
      disabled = "${var.disable_networkpolicy}"
    }
  }
  network_policy {
    enabled = "${var.disable_networkpolicy ? 0 : 1}"
  }
  node_config {
    machine_type = "${var.machine_type}"
    disk_size_gb = "${var.disk_size_gb}"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels {
      app = "crawler"
    }

    tags = ["${var.cluster_name}"]
  }
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone} --project ${var.project}"
  }
}

resource "google_container_node_pool" "bigpool" {
  name       = "bigpool"
  project    = "${var.project}"
  zone       = "${var.zone}"
  cluster    = "${google_container_cluster.cluster.name}"
  node_count = "${var.big_node_count}"

  node_config {
    machine_type = "n1-standard-2"
    disk_size_gb = "40"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels {
      app         = "gitlab"
      elastichost = "true"
    }

    tags = ["${var.cluster_name}"]
  }
}

resource "google_compute_firewall" "cluster-firewall" {
  project     = "${var.project}"
  name        = "default-allow-${var.cluster_name}"
  network     = "default"
  description = "Allow access to cluster (${var.cluster_name})"
  priority    = "1000"

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  target_tags   = ["${var.cluster_name}"]
  source_ranges = ["0.0.0.0/0"]
}
