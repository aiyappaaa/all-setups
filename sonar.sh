#!/bin/bash
# Launch an instance with port 9000 open and instance type t2.medium or t3.medium
# This script installs SonarQube 10.4.1 with Java 17 on Amazon Linux

# Install Java 17 (Amazon Corretto 17) - compatible with SonarQube 10.4.1
yum install -y java-17-amazon-corretto-devel

# Set Java 17 as default
alternatives --install /usr/bin/java java /usr/lib/jvm/java-17-amazon-corretto.x86_64/bin/java 1

# Verify Java installation
java -version

# Install SonarQube
cd /opt/
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.1.88267.zip
yum install -y unzip
unzip sonarqube-10.4.1.88267.zip

# Create sonar user (SonarQube cannot run as root)
useradd -m -s /bin/bash sonar

# Set ownership and permissions
chown -R sonar:sonar /opt/sonarqube-10.4.1.88267
chmod -R 755 /opt/sonarqube-10.4.1.88267

# Create logs directory with proper permissions
mkdir -p /opt/sonarqube-10.4.1.88267/logs
chown sonar:sonar /opt/sonarqube-10.4.1.88267/logs
chmod 755 /opt/sonarqube-10.4.1.88267/logs

# Required kernel parameters for Elasticsearch (used internally by SonarQube)
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf
sysctl -p

# Start SonarQube as the sonar user
su -s /bin/bash sonar -c "/opt/sonarqube-10.4.1.88267/bin/linux-x86-64/sonar.sh start"

# Wait for startup
sleep 45

# Check status
su -s /bin/bash sonar -c "/opt/sonarqube-10.4.1.88267/bin/linux-x86-64/sonar.sh status"

echo ""
echo "=========================================="
echo "SonarQube installation complete!"
echo "=========================================="
echo "Access SonarQube at: http://<your-server-ip>:9000"
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo "=========================================="
