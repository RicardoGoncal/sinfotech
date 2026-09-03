# 1. Captura o Availability Domain disponível
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# 2. Busca a imagem do Ubuntu 22.04 ARM
data "oci_core_images" "ubuntu_arm_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# 3. A Máquina Parruda (Coolify)
resource "oci_core_instance" "coolify_vm" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "coolify-server"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    assign_public_ip = false # Fica 'false' porque vamos atrelar o fixo ali embaixo
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_arm_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = file("~/.ssh/id_rsa.pub") 
  }
}

# 4. CAPTURA DA PLACA DE REDE E CRIAÇÃO DO IP FIXO
data "oci_core_vnic_attachments" "coolify_vnic_attachments" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.coolify_vm.id
  depends_on     = [oci_core_instance.coolify_vm] # Garante a ordem correta
}

data "oci_core_private_ips" "coolify_private_ips" {
  vnic_id = data.oci_core_vnic_attachments.coolify_vnic_attachments.vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "coolify_reserved_ip" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.coolify_private_ips.private_ips[0].id
  display_name   = "coolify-fixed-ip"
}