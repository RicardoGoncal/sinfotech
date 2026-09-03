terraform {
  backend "s3" {
    bucket   = "oci-terraform-state-bucket"
    key      = "vm-coolify/terraform.tfstate"
    region   = "us-ashburn-1"
    endpoint = "https://idjliws7gjtp.compat.objectstorage.us-ashburn-1.oraclecloud.com"
    
    shared_credentials_file     = "~/.oci/s3_credentials"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    use_path_style              = true
    
    # NOVAS LINHAS: Desabilitam o chunked encoding e chamadas extras de metadados
    skip_s3_checksum            = true 
    skip_metadata_api_check     = true 
  }
}