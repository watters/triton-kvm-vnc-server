variable "vnc_password" {
    default = "password"
}

data "triton_image" "ubuntu" {
  name        = "ubuntu-certified-16.04"
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
    image   = "${data.triton_image.ubuntu.id}"

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
            "sudo apt update && sudo apt upgrade -y",
            "sudo apt install -y xfce4 xfce4-goodies tightvncserver",
            "mkdir -p ~/.vnc",
        ]
        connection {
            type = "ssh"
            user = "ubuntu"
        }
    }

    provisioner "file" {
        source = "./.vnc/"
        destination = "/home/ubuntu/.vnc"

        connection {
            type = "ssh"
            user = "ubuntu"
        }
    }

    provisioner "remote-exec" {
        inline = [
            "set -x",
            "chmod 600 ~/.vnc/passwd",
            "chmod +x ~/.vnc/xstartup",
            "echo \"${var.vnc_password}\" | vncpasswd -f > ~/.vnc/passwd",
        ]

        connection {
            type = "ssh"
            user = "ubuntu"
        }
    }

    provisioner "file" {
        source = "vncserver@.service"
        destination = "/home/ubuntu/vncserver@.service"

        connection {
            type = "ssh",
            user = "ubuntu"
        }
    }

    provisioner "remote-exec" {
        inline = [
            "set -x",
            "sudo mv /home/ubuntu/vncserver@.service /etc/systemd/system/vncserver@.service",
            "sudo systemctl daemon-reload",
            "sudo systemctl enable vncserver@1.service",
            "sudo systemctl start vncserver@1",
        ]

        connection {
            type = "ssh",
            user = "ubuntu"
        }
    }

    provisioner "local-exec" {
        command = "ssh -oStrictHostKeyChecking=no -L 5901:127.0.0.1:5901 -N -f -l ubuntu ${triton_machine.kvm-desktop.primaryip}"
    }
}

output "kvm_desktop_ip" {
    value = "${triton_machine.kvm-desktop.primaryip}"
}