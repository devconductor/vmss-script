#!/bin/bash
# Script: Instalação do docker e adicionar usuário rancher para não pedir senha
# Modificações Roberto Mendonca - 14-05-2019
# Ajuste no modo de condeguir o IP do host
# Ajuste no comando de adicao do agente do rancher
# Adicao de rotate de logs e limpeza de containers e images antigas no host
# Adicao de instalação de agent splunk para monitoramento

# Variable Setup
AGENT_VERSION="v1.2.5"
LOCAL_IP=`ip route get 1.1.1.1 | grep -oP 'src \K\S+'`
STATUS=255
SLEEP=5
CRONFILE="/var/spool/cron/root"
CRONEXP="0 * * * * /sbin/logrotate -f /etc/logrotate.d/clear"
CRONFILE2="/opt/clear.sh"
CRONEXP2="0 0 * * * /bin/bash /opt/clear.sh"
CRONRLFILE="/etc/logrotate.d/clear"

## Adicionando usuário no sudoers
sudo chmod u+rw /etc/sudoers.d/waagent
echo $1 > /dev/null
sudo sed -i s/ALL\=\(ALL\)\ ALL/ALL\=\(ALL\)\ NOPASSWD\:\ ALL/g /etc/sudoers.d/waagent
echo $1 > /dev/null

## Adicionando repositorio do docker
#sudo tee /etc/yum.repos.d/docker.repo <<-'EOF'
#[docker-ce-stable]
#name=Docker CE Stable - $basearch
#baseurl=https://download.docker.com/linux/centos/7/$basearch/stable
#enabled=1
#gpgcheck=1
#gpgkey=https://download.docker.com/linux/centos/gpg
#EOF
#REPO=`ls -l /etc/yum.repos.d/docker*.repo |awk '{print$9}' |cut -d "/" -f 4`

## Adicionando repositorio do docker
yum-config-manager --add-repo  https://download.docker.com/linux/centos/docker-ce.repo

## Variaveis
VERSAO_DOCKER="docker-ce-18.06.3.ce-3.el7.x86_64"
#VERSAO_DOCKER_SE="docker-ce-selinux-17.03.1.ce-1.el7.centos"
REPO=`ls -l /etc/yum.repos.d/docker-ce.repo |awk '{print$9}' |cut -d "/" -f 4`


#Repo
if [ -z $REPO ]; then

        echo "O arquivo nao foi criado. Saindo..."
        exit 0

else
    	echo "Instalar versão do docker"
        sudo yum install -y --setopt=obsoletes=0 $VERSAO_DOCKER
echo -e '{
"storage-driver": "overlay2"
}
'>  /etc/docker/daemon.json
        sudo systemctl enable docker.service
        sudo sed -i s/dockerd/dockerd\ \-\-insecure\-registry\=portus\.conductor\.tecnologia\:5000/g /usr/lib/systemd/system/docker.service
        sudo systemctl daemon-reload
        sudo systemctl start docker
        sleep 5
    	echo "Docker instalado"
fi



## Subindo o rancher node
RANCHER_SERVER_URL=$2
SPLUNK_ADDRESS=$3
SPLUNK_AUTH=$4

echo "### Version  = $AGENT_VERSION"
echo "### Agent IP = $LOCAL_IP"
echo "### SPLUNK_ADDRESS = $SPLUNK_ADDRESS"
echo "### SPLUNK_AUTH = $SPLUNK_AUTH"

echo "# Installing Rancher Agent"
while [ $STATUS -gt 0 ]
do
  sleep $SLEEP
  OUTPUT=`sudo docker run -e "CATTLE_AGENT_IP=$LOCAL_IP" --rm --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.2.11 $RANCHER_SERVER_URL 2>&1` 
  STATUS=$?
  echo $OUTPUT
done


#Clear
if [ -f "$CRONFILE" ];
then
   echo "$CRONEXP" >> $CRONFILE
   echo "$CRONEXP2" >> $CRONFILE
   chmod 600 $CRONFILE
else
    	touch $CRONFILE
    echo "$CRONEXP" >> $CRONFILE
    echo "$CRONEXP2" >> $CRONFILE
        chmod 600 $CRONFILE
fi

if [ -f "$CRONRLFILE" ];
then
  echo -e "#!/bin/bash
  rotate 4
  hourly
  maxsize=20M
  compress
  delaycompress
  copytruncate
}" > $CRONRLFILE
else
  touch $CRONRLFILE
  echo -e "/var/lib/docker/containers/*/*.log {
  rotate 4
  hourly
  maxsize=20M
  compress
  delaycompress
  copytruncate
}" > $CRONRLFILE
fi

if [ -f "$CRONFILE2" ];
then
  echo -e '#!/bin/bash
/bin/docker rmi $(/bin/docker images --quiet --filter "dangling=true")
/bin/docker volume rm -f $(/bin/docker volume ls -q --filter "dangling=true")' > $CRONFILE2
else
  touch $CRONFILE2
  echo -e '#!/bin/bash
/bin/docker rmi $(/bin/docker images --quiet --filter "dangling=true")
/bin/docker volume rm -f $(/bin/docker volume ls -q --filter "dangling=true")' > $CRONFILE2
fi


#####splunk conf
cd /opt
pwd
wget -O splunkforwarder-7.2.3-06d57c595b80-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.3&product=universalforwarder&filename=splunkforwarder-7.2.3-06d57c595b80-Linux-x86_64.tgz&wget=true'
tar -xzvf splunkforwarder-7.2.3-06d57c595b80-Linux-x86_64.tgz
rm -rf splunkforwarder-7.2.3-06d57c595b80-Linux-x86_64.tgz
/opt/splunkforwarder/bin/splunk clone-prep-clear-config
/opt/splunkforwarder/bin/splunk set deploy-poll $SPLUNK_ADDRESS  --accept-license --answer-yes --auto-ports --no-prompt  -auth $SPLUNK_AUTH
/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --auto-ports --no-prompt
