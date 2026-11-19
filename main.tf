data "aws_ssm_parameter" "ubuntuAmi" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id" # verify available version
}

resource "aws_instance" "ec2-ubuntu-datawarehouse" {
  ami                         = data.aws_ssm_parameter.ubuntuAmi.value
  instance_type               = "m7i-flex.large" # verify available type
  associate_public_ip_address = true
  vpc_security_group_ids      = ["_"]  # enter your security group
  subnet_id                   = "_"  # enter your subnet
  key_name                    = "_" # enter only the name of the .pem file
  user_data = file("userdata.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

}

resource "null_resource" "sleep_example" {
  depends_on = [aws_instance.ec2-ubuntu-datawarehouse]

  provisioner "remote-exec" {
    inline = [
      "echo 'Sleeping for 30 seconds...'",
      "sleep 30",  # Sleep for 30 seconds
      "echo 'Sleep completed!'"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_") # enter file name
    }
  }
}

resource "null_resource" "install_docker" {
  depends_on = [aws_instance.ec2-ubuntu-datawarehouse, null_resource.sleep_example]

  provisioner "remote-exec" {
    inline = [
        "sudo apt update",
        "sudo apt upgrade -y",
        "sudo apt install -y ca-certificates curl",
        "sudo install -m 0755 -d /etc/apt/keyrings",
        "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
        "sudo chmod a+r /etc/apt/keyrings/docker.asc"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

  provisioner "file" {
    source      = "./docker.sources"        # Local path of docker.sources
    destination = "/tmp/docker.sources"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo install -m 0644 /tmp/docker.sources /etc/apt/sources.list.d/docker.sources", 
      "echo 'Esperando a que APT libere los bloqueos...'",
      "while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'APT ocupado. Esperando 5 segundos...'; sleep 5; done", 
      "sudo apt update",
      "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ubuntu"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }
}

resource "null_resource" "before_begin_dbt" {
  depends_on = [null_resource.install_docker]

  provisioner "remote-exec" {
    inline = [
        "sudo mkdir -p /dbt-core-production"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

  provisioner "file" {
    source      = "./docker-compose.yaml"        # Local path of docker-compose.yaml
    destination = "/tmp/docker-compose.yaml"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "file" {
    source      = "./Dockerfile"        # Local path of Dockerfile
    destination = "/tmp/Dockerfile"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/docker-compose.yaml /dbt-core-production/docker-compose.yaml",  
      "sudo mv /tmp/Dockerfile /dbt-core-production/Dockerfile"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}

resource "null_resource" "add_profile_dbt" {
  depends_on = [null_resource.before_begin_dbt]

  provisioner "file" {
    source      = "./profiles.yml"        # Local path of profiles.yml
    destination = "/tmp/profiles.yml"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/profiles.yml /dbt-core-production/dbt_project/.dbt/profiles.yml"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}

resource "null_resource" "after_dbt_init" {
  depends_on = [null_resource.add_profile_dbt]

  provisioner "file" {
    source      = "./dbt_project.yml"        # Local path of dbt_project.yml
    destination = "/tmp/dbt_project.yml"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/dbt_project.yml /dbt-core-production/dbt_project/dbt_project/dbt_project.yml"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}

resource "null_resource" "import_data_source" {
  depends_on = [null_resource.add_profile_dbt]

  provisioner "file" {
    source      = "./ecommerce_sales.csv"        # Local path of ecommerce_sales.csv 
    destination = "/tmp/ecommerce_sales.csv"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/ecommerce_sales.csv /dbt-core-production/dbt_project/dbt_project/seeds/ecommerce_sales.csv"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}

resource "null_resource" "initial_step" {
  depends_on = [null_resource.import_data_source]

  provisioner "remote-exec" {
    inline = [
        "sudo mkdir -p /dbt-core-production/dbt_project/dbt_project/models/initial"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

  provisioner "file" {
    source      = "./ini_ecommerce_sales.sql"         # Local path of initial transformation file
    destination = "/tmp/ini_ecommerce_sales.sql"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/ini_ecommerce_sales.sql /dbt-core-production/dbt_project/dbt_project/models/initial/ini_ecommerce_sales.sql"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}

resource "null_resource" "intermediate_step" {
  depends_on = [null_resource.import_data_source]

  provisioner "remote-exec" {
    inline = [
        "sudo mkdir -p /dbt-core-production/dbt_project/dbt_project/models/intermediate"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

  provisioner "file" {
    source      = "./int_ecommerce_sales.sql"        # Local path of intermediate transformation file
    destination = "/tmp/int_ecommerce_sales.sql"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/int_ecommerce_sales.sql /dbt-core-production/dbt_project/dbt_project/models/intermediate/int_ecommerce_sales.sql"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}

resource "null_resource" "final_step" {
  depends_on = [null_resource.import_data_source]

  provisioner "remote-exec" {
    inline = [
        "sudo mkdir -p /dbt-core-production/dbt_project/dbt_project/models/final"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

  provisioner "file" {
    source      = "./final_customer.sql"        # Local path of final transformation file
    destination = "/tmp/final_customer.sql"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "file" {
    source      = "./final_product.sql"        # Local path of final transformation file
    destination = "/tmp/final_product.sql"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "file" {
    source      = "./final_order.sql"        # Local path of final transformation file
    destination = "/tmp/final_order.sql"     # Destination path on the EC2 instance

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"           # Ubuntu default user
      private_key = file("./_")        # Path to your private key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/final_customer.sql /dbt-core-production/dbt_project/dbt_project/models/final/final_customer.sql",
      "sudo mv /tmp/final_product.sql /dbt-core-production/dbt_project/dbt_project/models/final/final_product.sql",
      "sudo mv /tmp/final_order.sql /dbt-core-production/dbt_project/dbt_project/models/final/final_order.sql"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.ec2-ubuntu-datawarehouse.public_ip
      user        = "ubuntu"
      private_key = file("./_")
    }
  }

}








