#!/bin/bash

# Ensure we're using Ubuntu
sudo apt update
sudo apt upgrade -y

# Install Java
sudo apt install -y openjdk-21-jdk-headless curl

# Create the Minecraft directory
mkdir -p "$HOME/minecraft"
cd "$HOME/minecraft"

# Download server.jar
curl -o server.jar https://piston-data.mojang.com/v1/objects/e6ec2f64e6080b9b5d9b471b291c33cc7f509733/server.jar

# Accept EULA
echo "eula=true" > eula.txt

# Create systemd service (needs sudo tee to write as root)
sudo tee /etc/systemd/system/minecraft.service > /dev/null <<EOF
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/minecraft
ExecStart=/usr/bin/java -Xms2G -Xmx6G -jar server.jar nogui
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable minecraft
sudo systemctl start minecraft

# Show service status
sudo systemctl status minecraft
