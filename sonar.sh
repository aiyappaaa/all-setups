#!/bin/bash
# Launch an instance with port 9000 open and instance type t2.medium (or t3.medium recommended)

# Install Java 21 (Amazon Corretto 21)
yum install -y java-21-amazon-corretto-devel

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

# Required kernel parameters for Elasticsearch (used internally by SonarQube)
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf
sysctl -p

# Start SonarQube as the sonar user
su -s /bin/bash sonar -c "/opt/sonarqube-10.4.1.88267/bin/linux-x86-64/sonar.sh start"

echo "SonarQube started. Access it at http://<your-server-ip>:9000"
echo "Default credentials => user: admin | password: admin"
