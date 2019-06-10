#!/bin/bash
# Script: Instalação do docker-engine versão 17.03.1.ce e adicionar usuário rancher para não pedir senha
## Validando se foi passada as variaveis no comando
echo "## Validando variaveis"
if [ -z "$1" ];
then
  echo "# A senha nao foi passada"
  exit 2
else
  echo "# Senha detectada"
fi
if [ -z "$2" ];
then
  echo "# URL do Rancher nao detectada"
  exit 2
else
  echo "# URL Detectada"
fi

## Adicionando usuário no sudoers
sudo chmod u+rw /etc/sudoers.d/waagent
echo $1 > /dev/null
sudo sed -i s/ALL\=\(ALL\)\ ALL/ALL\=\(ALL\)\ NOPASSWD\:\ ALL/g /etc/sudoers.d/waagent
echo $1 > /dev/null

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

## Adicionando repositorio do docker
## Variaveis
VERSAO_DOCKER="docker-ce-17.03.3.ce-1.el7.x86_64"

        echo "Instalar versão do docker"
        sudo yum install -y --setopt=obsoletes=0 $VERSAO_DOCKER
        sudo systemctl enable docker.service
        sudo sed -i s/dockerd/dockerd\ \-\-insecure\-registry\=portus\.conductor\.tecnologia\:5000/g /usr/lib/systemd/system/docker.service
        sudo systemctl daemon-reload
        sudo service docker start
        sleep 5


## Subindo o rancher node
# Variable Setup
echo "# Setting Variables"
HOST_URL=$2
AGENT_VERSION="v1.2.5"
LOCAL_IP=`ifconfig eth0 | awk '/inet /{print substr($2,1)}'`
STATUS=255
SLEEP=5
echo "### Server   = $HOST_URL"
echo "### Version  = $AGENT_VERSION"
echo "### Agent IP = $LOCAL_IP"

echo "# Installing Rancher Agent"
while [ $STATUS -gt 0 ]
do
  sleep $SLEEP
  OUTPUT=`sudo docker run -e "CATTLE_AGENT_IP=$LOCAL_IP" -d --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:$AGENT_VERSION $HOST_URL 2>&1`
  STATUS=$?
  echo $OUTPUT
done

exit $STATUS


