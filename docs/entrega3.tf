terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}
provider "docker" {}
resource "docker_container" "jenkins_docker" {
  name         = "jenkins-docker"
  image        = "docker:dind"
  privileged   = true
  networks_advanced {
    name = "jenkins"
    aliases = ["docker"]
  }
  env = [
    "DOCKER_TLS_CERTDIR=/certs",
  ]

  ports {
    internal = 2376
    external = 2376
  }
  volumes {
    container_path = "/certs/client"
    host_path      = "/home/josenr/VS/jenkis_practica/jenkins-docker-certs"
    read_only      = false
  }
  volumes {
    container_path = "/var/jenkins_home"
    host_path      = "/home/josenr/VS/jenkis_practica/jenkins-data"
    read_only      = false
  }

  
}

resource "docker_container" "jenkins_blueocean" {
  name         = "jenkins-blueocean"
  image        = "myjenkins-blueocean:2.426.2-1"
  privileged   = true
  networks_advanced {
    name = "jenkins"
  }
  env = [
    "DOCKER_HOST=tcp://docker:2376",
    "DOCKER_CERT_PATH=/certs/client",
    "DOCKER_TLS_VERIFY=1",
    "JAVA_OPTS=-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true",
  ]
  ports {
    internal = 8080
    external = 8080
  }
  ports {
    internal = 50000
    external = 50000
  }
  volumes {
    container_path = "/var/jenkins_home"
    host_path      = "/home/josenr/VS/jenkis_practica/jenkins-data"
    read_only      = false
  }
  volumes {
    container_path = "/certs/client"
    host_path      = "/home/josenr/VS/jenkis_practica/jenkins-docker-certs"
    read_only      = false
  }
  volumes {
    container_path = "/home"
    host_path      = "/home"
    read_only      = false
  }
  restart = "on-failure"
}
