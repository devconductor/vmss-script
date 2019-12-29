sudo sed -i s/ALL\=\(ALL\)\ ALL/ALL\=\(ALL\)\ NOPASSWD\:\ ALL/g /etc/sudoers.d/waagent
sudo -s
adduser k8s
echo "k8s:teste@k8s" | chpasswd
gpasswd -a k8s wheel
gpasswd -a k8s docker

timedatectl set-timezone "America/Sao_Paulo"
curl https://releases.rancher.com/install-docker/19.03.sh > sh.sh
bash sh.sh
