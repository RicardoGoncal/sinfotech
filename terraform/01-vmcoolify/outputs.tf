output "coolify_public_ip" {
  description = "O IP Fixo Público da sua VM"
  value       = oci_core_public_ip.coolify_reserved_ip.ip_address
}

output "vcn_id" {
  description = "OCID da VCN do Coolify"
  value       = oci_core_vcn.coolify_vcn.id
}

output "subnet_id" {
  description = "OCID da Sub-rede Pública"
  value       = oci_core_subnet.public_subnet.id
}