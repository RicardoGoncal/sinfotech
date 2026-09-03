terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
}

# Pegando o namespace do seu tenant (necessário para Object Storage na OCI)
data "oci_objectstorage_namespace" "tenant_namespace" {
  compartment_id = var.tenancy_ocid
}

# Criando o Bucket para o tfstate
resource "oci_objectstorage_bucket" "terraform_state_bucket" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.tenant_namespace.namespace
  name           = "oci-terraform-state-bucket"
  access_type    = "NoPublicAccess"
  
  # Habilitando versionamento para manter histórico e evitar perda do state
  versioning     = "Enabled" 
}