EC2 + RDS + Bastion Host en AWS con Terraform

Este proyecto lo hice para montar una arquitectura real en AWS. La idea es tener una aplicación Flask donde los usuarios se registran, y esos datos se guardan en una base de datos PostgreSQL (RDS). Todo está montado usando Terraform para automatizar la infraestructura, y siguiendo buenas prácticas de red y seguridad.
Tecnologías que usé

    AWS EC2 para el servidor de la app Flask

    AWS RDS (PostgreSQL) para guardar los registros

    AWS Bastion Host para acceder a recursos privados de forma segura

    Terraform para levantar toda la infraestructura

    Python + Flask para el backend

    HTML y CSS para el formulario

    (Y si quiero, lo puedo correr en Docker también)


Qué arquitectura monté

    Una VPC que yo definí con:

        Subred pública (para el EC2 y el Bastion Host)

        Subred privada (para la base de datos RDS)

    El Bastion solo acepta SSH desde mi IP

    El EC2 está preparado para HTTP (puerto 80) y Gunicorn (puerto 8000)

    La base de datos no es pública: solo puede acceder el Bastion y el servidor web

    Todo eso está en Terraform, hasta los route tables y las IPs

Cómo lo desplegué

    Primero creé un archivo .env con las variables de entorno:

    DB_HOST=...
    DB_NAME=postgres
    DB_USER=dbuser
    DB_PASS=...
    DB_PORT=5432

    Corrí terraform init y después terraform apply

    Me conecté por SSH al Bastion para acceder a la RDS si hacía falta

    Subí la app al EC2 (puede ser por SSH o con Docker)

    Y ya con eso, la aplicación quedó accesible desde el navegador

Enlace al repo

👉 https://github.com/Jdavid-cruz/EC2-BASTION-HOST-RDS-
¿Por qué hice esto?

Quiero trabajar como administrador Administrador AWS y Arquitecto de Soluciones en AWS, y con este proyecto muestro que puedo construir una infraestructura segura, bien organizada, y que funciona. Desde la red hasta la app.
