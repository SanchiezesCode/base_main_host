#!/bin/bash

# Запрашиваем переменную для замены (пользователь введет значение при запуске)
read -p "Введите новое значение для host_x: " new_host

echo "Обновляем пакеты..."
sudo apt-get update

echo "Устанавливаем необходимые пакеты..."
sudo apt-get install -y ca-certificates curl

echo "Устанавливаем директорию для ключей..."
sudo install -m 0755 -d /etc/apt/keyrings

echo "Добавляем GPG-ключ Docker..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "Добавляем репозиторий Docker в источники Apt..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Обновляем списки пакетов..."
sudo apt-get update

echo "Устанавливаем Docker и необходимые компоненты..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Проверяем установку Docker..."
sudo docker --version
sudo docker compose version

echo "Добавляем текущего пользователя в группу Docker..."
sudo usermod -aG docker $USER

echo "Пожалуйста, перезагрузитесь или выйдите и войдите снова для применения изменений."

cd ~

if ! command -v git &> /dev/null
then
    echo "Git не установлен. Устанавливаю Git..."
    sudo apt update
    sudo apt install -y git
else
    echo "Git уже установлен."
fi

echo "Клонирую репозиторий..."
git clone https://github.com/SanchiezesCode/base_main_host.git

echo "Репозиторий успешно клонирован!"

cd base_main_host/

# Переходим в директорию с конфигами
cd config/promtail

# Заменяем host_x на введенное значение
echo "Изменяем значение host_x на $new_host в promtail.yaml"
sed -i "s/host_x/$new_host/g" promtail.yaml

echo "Значение host_x успешно изменено в promtail.yaml на $new_host."

# Устанавливаем Node Exporter
echo "Устанавливаем Node Exporter..."

NODE_EXPORTER_VERSION="1.9.0"

cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
tar xvfz node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz
cd node_exporter-$NODE_EXPORTER_VERSION.linux-amd64

# Перемещаем и настраиваем
sudo mv node_exporter /usr/bin/
sudo rm -rf /tmp/node_exporter*

# Создаём пользователя для Node Exporter
sudo useradd -rs /bin/false node_exporter
sudo chown node_exporter:node_exporter /usr/bin/node_exporter

# Создаём сервис для Node Exporter
cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Запускаем Node Exporter
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Проверяем версию Node Exporter
node_exporter --version

# Возвращаемся в домашнюю директорию
cd ~

# Запускаем docker-compose
echo "Запускаем docker-compose..."
sudo docker compose -f ~/base_main_host/docker-compose.yaml up -d

echo "Docker Compose успешно запущен!"
