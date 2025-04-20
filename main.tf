# Configuro el provider de AWS y la región donde voy a desplegar toda la infraestructura
provider "aws" {
  region = "us-east-1"
}

# Creo mi propia VPC personalizada con soporte DNS activado para poder usar nombres en vez de IPs
resource "aws_vpc" "mi_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "mi_vpc"
  }
}

# Subred pública para alojar el bastion host y el servidor web. Activo IP pública automática al lanzar instancias.
resource "aws_subnet" "subred_publica" {
  vpc_id = aws_vpc.mi_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

# Subred privada para recursos internos (como base de datos). No tendrá IP pública.
resource "aws_subnet" "subred_privada" {
  vpc_id = aws_vpc.mi_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false
}

# RDS necesita al menos dos subredes privadas en distintas zonas de disponibilidad.
resource "aws_subnet" "subred_privada_2" {
  vpc_id = aws_vpc.mi_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "subred_privada_2"
  }
}

# Creo el Internet Gateway para darle salida a internet a la VPC (solo a través de subred pública)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.mi_vpc.id

  tags = {
    Name = "mi_internet_gateway"
  }
}

# Tabla de rutas pública: todo el tráfico va hacia internet a través del Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Asocio la tabla de rutas pública con la subred pública
resource "aws_route_table_association" "public_assoc" {
  subnet_id = aws_subnet.subred_publica.id
  route_table_id = aws_route_table.public_rt.id
}

# Creo una IP elástica (EIP) para asignársela al NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# El NAT Gateway me permite dar salida a internet a la subred privada, sin exponerla directamente
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.subred_publica.id
}

# Tabla de rutas para la subred privada: permite conexión a internet mediante el NAT Gateway
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.mi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private_rt"
  }
}

# Asocio esta tabla privada con una de las subredes privadas
resource "aws_route_table_association" "private_assoc" {
  subnet_id = aws_subnet.subred_privada.id
  route_table_id = aws_route_table.private_rt.id
}

# Este grupo de subredes privadas se usará específicamente para la base de datos RDS
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.subred_privada.id,
    aws_subnet.subred_privada_2.id
  ]

  tags = {
    Name = "rds_subnet_group"
  }
}

# Instancia de base de datos RDS en PostgreSQL, en subred privada y no accesible desde internet
resource "aws_db_instance" "mi_rds" {
  identifier             = "registro-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "17.2"
  instance_class         = "db.t3.micro"
  username               = "dbuser"
  password               = "contrasena123"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
}

# Security Group para RDS: solo acepta conexiones del Bastion Host y del servidor web
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Permitir el tráfico desde el Bastion Host y Web Server"
  vpc_id      = aws_vpc.mi_vpc.id

  ingress {
    description     = "Acceso desde Bastion Host"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description     = "Acceso desde servidor web"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-rds"
  }
}

# Security Group para Bastion Host: permite acceso SSH solo desde mi IP
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Permitir SSH desde mi IP hacia el bastion"
  vpc_id      = aws_vpc.mi_vpc.id

  ingress {
    description = "SSH desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["92.59.51.182/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_bastion"
  }
}

# Par de claves públicas para acceder por SSH
resource "aws_key_pair" "bastion_key" {
  key_name   = "mi-clave-terraform"
  public_key = file("C:/Users/juanr/Documents/misclavesppk/mi-clave-terraform.pub")
}

resource "aws_key_pair" "mi_nueva_clave" {
  key_name   = "mi-nueva-clave"
  public_key = file("C:/Users/juanr/Documents/misclavesppk/mi-nueva-clave.pub")
}

# Instancia EC2 para Bastion Host, ubicada en subred pública con IP pública
resource "aws_instance" "bastion" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subred_publica.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.mi_nueva_clave.key_name
  associate_public_ip_address = true

  tags = {
    Name = "bastion_host"
  }
}

# Security Group para el servidor web: permite HTTP, SSH desde mi IP y puerto 8000 (gunicorn)
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Permitir HTTP y SSH"
  vpc_id      = aws_vpc.mi_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["92.59.51.182/32"]
  }

  ingress {
    description = "Gunicorn"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_web"
  }
}

# Instancia EC2 para alojar mi aplicación web (Flask). También está en subred pública.
resource "aws_instance" "web_server" {
  ami                         = "ami-084568db4383264d4"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.subred_publica.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  key_name                    = aws_key_pair.mi_nueva_clave.key_name
  associate_public_ip_address = true

  tags = {
    Name = "web_server"
  }
}

# Output que me muestra la IP del Bastion Host al final del despliegue
output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}
