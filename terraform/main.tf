variable "vnc_password" {
    default = "password"
}

data "triton_image" "kvm-vnc" {
  name        = "kvm-vnc"
  type        = "zvol"
  most_recent = true
}

data "triton_network" "public" {
    name = "Joyent-SDC-Public"
}

resource "triton_firewall_rule" "vnc_allow_ssh" {
   rule    = "FROM any TO tag vnc_allow_ssh ALLOW tcp PORT 22"
   enabled = true
}

resource "triton_machine" "kvm-desktop" {
    name = "kvm-desktop"
    package = "k4-general-kvm-15.75G"
    image   = "${data.triton_image.kvm-vnc.id}"

    tags = {
        vnc_allow_ssh = "true"
    }

    firewall_enabled = true
    depends_on = ["triton_firewall_rule.vnc_allow_ssh"]

    networks = [
        "${data.triton_network.public.id}"
    ]

    provisioner "remote-exec" {
        inline = [
            "set -x",
            "echo \"${var.vnc_password}\" | vncpasswd -f > ~/.vnc/passwd",
        ]

        connection {
            type = "ssh"
            user = "ubuntu"
        }
    }
}

output "ssh_tunnel_command" {
    value = "ssh -oStrictHostKeyChecking=no -L 5901:127.0.0.1:5901 -N -f -l ubuntu ${triton_machine.kvm-desktop.primaryip}"
}