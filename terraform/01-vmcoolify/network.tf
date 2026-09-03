# 1. A Rede Principal (VCN)
resource "oci_core_vcn" "coolify_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "coolify-vcn"
}

# 2. Internet Gateway
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.coolify_vcn.id
  display_name   = "coolify-igw"
  enabled        = true
}

# 3. Tabela de Roteamento (Apontando para a Internet)
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.coolify_vcn.id
  display_name   = "coolify-public-rt"

  route_rules {
    network_entity_id = oci_core_internet_gateway.igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

# 4. Security List (Firewall) - entrada travada no minimo necessario
resource "oci_core_security_list" "coolify_sec_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.coolify_vcn.id
  display_name   = "coolify-sec-list"

  # Saida (Egress): Acesso total a internet (o servidor precisa puxar imagens, certs, etc.)
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Ingress: SSH - SOMENTE do teu IP de administracao
  ingress_security_rules {
    protocol = "6" # TCP
    source   = var.ssh_admin_cidr
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress: HTTP - publico (apps + desafio HTTP-01 do Let's Encrypt)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # Ingress: HTTPS - publico (apps e o painel via https://coolify.sinfotechs.cloud)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress: Painel Coolify (8000) - SOMENTE do teu IP.
  # O acesso normal e via dominio na 443; a 8000 fica so como porta de emergencia.
  ingress_security_rules {
    protocol = "6" # TCP
    source   = var.ssh_admin_cidr
    tcp_options {
      min = 8000
      max = 8000
    }
  }

  # Ingress: ICMP Path MTU Discovery (type 3, code 4) - necessario pra conexoes nao travarem
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

# 5. Subnet Publica Unica
resource "oci_core_subnet" "public_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.coolify_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "coolify-subnet"
  route_table_id             = oci_core_route_table.public_rt.id
  security_list_ids          = [oci_core_security_list.coolify_sec_list.id]
  prohibit_public_ip_on_vnic = false
}
