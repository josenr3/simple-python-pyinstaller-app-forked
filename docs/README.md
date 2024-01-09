configurar jenkis


Esta es la explicación de la entrega de la práctica 3, en mi caso la he realizado sólo.

La explicación será por orden de como lo he realizado.
En mi caso he tenido que hacer las prácticas autodidacta debido a mi situación laboral y he encontrado problemas que seguro se resolvieron en clase, realizando la práctica de svc me encontré con el problema de que git no soportaba la autenticación a través de username y password por lo que tardé bastante en descubrir que desde hace bastante tiempo las acciones que se haga a través de la consola con git siguen un proceso de autenticación mediante tokens.

La imagen de de jenkins modificada es la siguiente:

	FROM jenkins/jenkins:2.426.2-jdk17
	USER root
	RUN apt-get update && apt-get install -y lsb-release
	RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
	  https://download.docker.com/linux/debian/gpg
	RUN echo "deb [arch=$(dpkg --print-architecture) \
	  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
	  https://download.docker.com/linux/debian \
	  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
	RUN apt-get update && apt-get install -y docker-ce-cli
	USER jenkins
	RUN jenkins-plugin-cli --plugins "blueocean:1.27.9 docker-workflow:572.v950f58993843"

La seguí del tutorial que es la misma que la imagen de las diapositivas se ejecutan los comandos indicados y diría que no tuve mucho problema con este asunto.

Construí la imagen con el comando facilitado en las diapositivas:

	docker build -t myjenkins-blueocean:2.426.2-1 .
	
Seguidamente cree el archivo de terraform para desplegar los contenedores de la práctica que sigue el siguiente formato:

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

	  command = ["--storage-driver", "overlay2"]
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
	
En este archivo cree los dos contenedores el contenedor de docker in docker y el de jenkis con la imagen personalizada anterior, lo iré explicando por fragmentos:

	terraform {
     required_providers {
       docker = {
         source  = "kreuzwerker/docker"
         version = "~> 3.0.1"
       }
     }
   }
   
En esta sección, indico que este archivo de Terraform requiere el proveedor de Docker de la fuente "kreuzwerker/docker" por seguir un poco el modelo de las clases con una versión aproximada de 3.0.1.

	provider "docker" {}

Aquí se declara el proveedor de Docker que se utilizará para gestionar los recursos de Docker.

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

	  command = ["--storage-driver", "overlay2"]
	}
	
En este fragmento configuramos el contenedor de docker in docker con la imagen de docker:dind, indicando tambien que se usará la red jenkins que tenía creada, seguidamente establecemos la variable de entorno para configurar el contenedor docker para que utilice un directorio específico para los certificados TLS, indicamos los puertos predeterminados seguidamente, e indicamos los volumenes a utilizar por parte del contenedor, aquí tuve algun problema con el host_path porque no lo entendía del todo moví la ubicación de los volumenes y lo indiqué y creo que funcionó correctamente y el comando especifica el uso de controlador de almacenamiento overlay2 que es responsable de cómo se almacena y gestiona los datos dentro del contenedor docker esta instrucción me dió algunos problemas además de que tuve que buscar su funcionalidad para comprenderlo mejor, basicamente gana en eficiencia y rendimiento.

ACTUALIZACIÓN: Al añadir aliases = ["docker"] ya funciona correctamentente debido a que se le permite a jenkis conectarse al contenedor de docker a través de este alias.

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

Vamos con la última parte de este archivo que es el contenedor de jenkins el cúal usa la imagen creada con el Dockerfile, en el que se otorga los privilegios necesarios, se indica la red anteriormente mencionada y se definen las variables de entorno en la que DOCKER_HOST=tcp://docker:2376 indica la ubicación del demonio de Docker (con este asunto he tenido problemas y no he conseguido a solucionarlo, en el video lo muestro), DOCKER_CERT_PATH=/certs/client ubicacion del directorio que contiene los certificados, DOCKER_TLS_VERIFY=1 se debe verificar la autenticidad del servidor de docker al establecer una conexión segura y AVA_OPTS=-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true esta variable de entorno se refiere a las opciones de Java para Jenkins y específicamente habilita la opción que permite la comprobación local de Git en Jenkins. Seguidamente establecemos los puertos que indica el tutorial, los volumenes a usar y la instrucción que establece la política de reinicio del contenedor en caso de que falle.

Para ejecutar este archivo lanzó los comandos 'terraform fmt' para la actualización automática de las configuraciones en el directorio para mejorar la legibilidad y la consistencia (textualmente de las diapositivas), seguidamente 'terraform validate' para aegurarnos de que la configuración está correcta y 'terraform apply' para desplegar los contenedores.

 
 Seguidamente se hace el fork del repositorio que indica la guía y ejecutamos el comando 'git remote add "nombre" "url" si no estoy equivocado, luego creo la carpeta main y en mi caso copieé todos los archivos de la rama master en la main y subí el Jenkisfile y algún otro archivo realizando pruebas siguiendo los comandos vistos en clase.
 
 En la configuración de jenkins segí el tutorial.
 
 Ejecutando 'docker logs jenkins-blueocean' conseguí el token de acceso, seguidamente me cree mi cuenta con user y password, creé el pipeline con la url del repositorio forkeado indicando la rama que se usará que es la main primero indicando la definicion que serie tipo Pipeline script from SCM indicando que se tratá de GIT y luego el script, pero básicamente es copiar el del tutorial:
 
 	pipeline {
	    agent none
	    options {
		skipStagesAfterUnstable()
	    }
	    stages {
		stage('Build') {
		    agent {
		        docker {
		            image 'python:3.12.1-alpine3.19'
		        }
		    }
		    steps {
		        sh 'python -m py_compile sources/add2vals.py sources/calc.py'
		        stash(name: 'compiled-results', includes: 'sources/*.py*')
		    }
		}
		stage('Test') {
		    agent {
		        docker {
		            image 'qnib/pytest'
		        }
		    }
		    steps {
		        sh 'py.test --junit-xml test-reports/results.xml sources/test_calc.py'
		    }
		    post {
		        always {
		            junit 'test-reports/results.xml'
		        }
		    }
		}
		stage('Deliver') { 
		    agent any
		    environment { 
		        VOLUME = '$(pwd)/sources:/src'
		        IMAGE = 'cdrx/pyinstaller-linux:python2'
		    }
		    steps {
		        dir(path: env.BUILD_ID) { 
		            unstash(name: 'compiled-results') 
		            sh "docker run --rm -v ${VOLUME} ${IMAGE} 'pyinstaller -F add2vals.py'" 
		        }
		    }
		    post {
		        success {
		            archiveArtifacts "${env.BUILD_ID}/sources/dist/add2vals" 
		            sh "docker run --rm -v ${VOLUME} ${IMAGE} 'rm -rf build dist'"
		        }
		    }
		}
	    }
	}
