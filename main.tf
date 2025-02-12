#===================================================================================================
# specifying the google provdiers and providing the credentials and the var is declared in
provider "google" {
  project = var.project_id
  region  = var.region_name
  zone    = var.zone_name
}


# #===================================================================================================
# #  for enable_apis into gcp main calling functions
locals {
  api_set_service = var.enable_apis ? toset(var.activate_apis_service) : []
}
resource "google_project_service" "project_api" {
  for_each                   = local.api_set_service
  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = true
}


#===================================================================================================
# VPC A Google Virtual Private Network (VPC), Subnets within the VPC, Secondary ranges for the subnets (if applicable)

resource "google_compute_network" "vpc_network" {
  name                    = var.vpc_network_name
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
  project = var.project_id
}

resource "google_compute_subnetwork" "public_subnetwork" {
  name                     = var.dev_subnet_name
  ip_cidr_range            = var.dev_ip_cidr_range
  region                   = var.region_name
  network                  = google_compute_network.vpc_network.name
  project = var.project_id
  private_ip_google_access = true
  # secondary_ip_range = [
  #   {
  #     range_name    = var.dev_secondary_rangename
  #     ip_cidr_range = var.dev_secondary_iprange
  #   },
  #   {
  #     range_name    = "gke-us-central1-clarity-dev-com-9539a8e7-gke-services-3944d1e3"
  #     ip_cidr_range = "10.8.0.0/20"
  #   },
  # ]

secondary_ip_range {
    range_name    = var.dev_secondary_rangename
    ip_cidr_range = var.dev_secondary_iprange
  }

  secondary_ip_range {
    range_name    = "gke-us-central1-clarity-dev-com-9539a8e7-gke-services-3944d1e3"
    ip_cidr_range = "10.8.0.0/20"
  }



  log_config {
    aggregation_interval = var.dev_aggregation_interval
    flow_sampling        = var.dev_flow_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# #======================================================================
# creating the composer


resource "google_composer_environment" "test" {
  name    = var.dev_composer_name
  region  = var.region_name
  project = var.project_id
  depends_on = [google_service_account.test]
  config {
environment_size = "ENVIRONMENT_SIZE_SMALL"
    #  node_count = var.dev_node_count


    node_config {
      network    = google_compute_network.vpc_network.name
      subnetwork = google_compute_subnetwork.public_subnetwork.name
      service_account = google_service_account.test.name
      ip_allocation_policy {
        cluster_secondary_range_name = var.dev_secondary_rangename
      }
    }
    software_config {
      image_version  = var.dev_image_version
      pypi_packages = {
        pymssql                                  = ">=2.1.5"    
        google-cloud-storage                     = ""
        fsspec                                   = "==2021.7.0"
        gcsfs                                    = "==2021.7.0"
        apache-airflow-providers-common-sql      = ">=1.3.1"
        apache-airflow-providers-microsoft-mssql = ""
        apache-airflow-providers-google          = ">= 2.0.0"
      }
    }
      workloads_config {
      scheduler {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
        count      = 1
      }
      web_server {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
      }
      worker {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
        min_count  = 1
        max_count  = 3
      }
    }
  }
}



resource "google_service_account" "test" {
  account_id   = var.service_ac_id
  display_name = "Test Service Account for Composer Environment"
  project = var.project_id
}

resource "google_project_iam_member" "composer-worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.test.email}"
}

resource "google_project_iam_member" "composer-service-agent-v2-ext" {
  project = var.project_id
   role    = "roles/composer.ServiceAgentV2Ext"
  member  = "serviceAccount:${google_service_account.test.email}"
}
# #===================================================================================================
# # main functions for bucket creation
resource "google_storage_bucket" "first-demo" {
  name     = var.bucket_name_var
  location = var.region_name
  project = var.project_id
}


# #===================================================================================================
# # topics and subscrpt main functions

resource "google_pubsub_topic" "example" {
  name = var.dev_topic_name
  project = var.project_id
}

resource "google_pubsub_subscription" "example" {
  name  = var.dev_subscription_name
  topic = google_pubsub_topic.example.name
  project = var.project_id
  ack_deadline_seconds = 20

  labels = {
    foo = "bar"
  }

}

##===========================================================================================================

#Below is the configuration for qa Environment

#===================================================================================================
# VPC A Google Virtual Private Network (VPC), Subnets within the VPC, Secondary ranges for the subnets (if applicable)

resource "google_compute_subnetwork" "qa_subnetwork" {
  name                     = var.qa_subnet_name
  ip_cidr_range            = var.qa_ip_cidr_range
  region                   = var.qa_region_name
  network                  = google_compute_network.vpc_network.name
  private_ip_google_access = true
  # secondary_ip_range = [
  #   {
  #     range_name    = var.qa_secondary_rangename
  #     ip_cidr_range = var.qa_secondary_iprange
  #   },
  #   {
  #     range_name    = "gke-us-central1-clarity-qa-comp-b85bfe90-gke-services-e1ad4b35"
  #     ip_cidr_range = "10.212.64.0/20"
  #   },
  # ]
   secondary_ip_range {
      range_name    = var.qa_secondary_rangename
      ip_cidr_range = var.qa_secondary_iprange
    }
	secondary_ip_range {
      range_name    = "gke-us-central1-clarity-qa-comp-b85bfe90-gke-services-e1ad4b35"
      ip_cidr_range = "10.212.64.0/20"
    }

  log_config {
    aggregation_interval = var.qa_aggregation_interval
    flow_sampling        = var.qa_flow_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# #======================================================================
# creating the composer


resource "google_composer_environment" "qa_composer" {
  name    = var.qa_composer_name
  region  = var.qa_region_name
  project = var.project_id
  depends_on = [google_service_account.test]
  config {
    node_config {
      network      = google_compute_network.vpc_network.name
      subnetwork   = google_compute_subnetwork.qa_subnetwork.name

      service_account = google_service_account.test.name
      ip_allocation_policy {
        cluster_secondary_range_name = var.qa_secondary_rangename
      }
    }
    software_config {
      image_version  = var.qa_image_version
        pypi_packages = {
        pymssql                                  = ">=2.1.5"    
        google-cloud-storage                     = ""
        fsspec                                   = "==2021.7.0"
        gcsfs                                    = "==2021.7.0"
        apache-airflow-providers-common-sql      = ">=1.3.1"
        apache-airflow-providers-microsoft-mssql = ""
        apache-airflow-providers-google          = ">= 2.0.0"
      }
    }
    workloads_config {
      scheduler {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
        count      = 1
      }
      web_server {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
      }
      worker {
        cpu        = 0.5
        memory_gb  = 1.875
        storage_gb = 1
        min_count  = 1
        max_count  = 3
      }
    }

  }
}

# #===================================================================================================
# # main functions for bucket creation
resource "google_storage_bucket" "qa-test-bucket" {
  name     = var.qa_bucket_name_var
  location = var.qa_region_name
}

# #===================================================================================================
# # topics and subscrpt main functions

resource "google_pubsub_topic" "qa_pubsub_topic" {
  name = var.qa_topic_name
}

resource "google_pubsub_subscription" "qa_pubsub_subscription" {
  name  = var.qa_subscription_name
  topic = google_pubsub_topic.qa_pubsub_topic.name

  ack_deadline_seconds = 20

  labels = {
    foo = "bar"
  }

}
