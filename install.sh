#!/bin/bash

# n8n with Caddy and Cloudflare Installation Wizard
# Simple setup for your n8n workflow automation

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display messages
show_message() {
  echo -e "${BLUE}-------------------------------------${NC}"
  echo -e "${GREEN}$1${NC}"
  echo -e "${BLUE}-------------------------------------${NC}"
}

# Welcome message
clear
echo -e "${GREEN}Welcome to the n8n Setup Wizard!${NC}"
echo -e "This will help you set up n8n on your server with secure access."
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}This setup needs administrator permissions.${NC}"
    echo -e "Please run this script with sudo: ${BLUE}sudo ./install.sh${NC}"
    exit 1
fi

# Check for SSL files with friendly message
if [ ! -f "ssl/cert.pem" ] || [ ! -f "ssl/key.key" ]; then
    echo -e "${YELLOW}Missing SSL certificate files.${NC}"
    echo -e "Please place your Cloudflare SSL files in the ssl folder:"
    echo -e "  • ${BLUE}cert.pem${NC} - Your SSL certificate"
    echo -e "  • ${BLUE}key.key${NC} - Your SSL private key"
    echo ""
    echo -e "You can get these from your Cloudflare dashboard."
    exit 1
fi

# Simple configuration inputs
show_message "Let's set up your n8n website address"
echo -e "We'll need two pieces of information:"
echo -e "1. Your main domain (like ${BLUE}example.com${NC})"
echo -e "2. The subdomain where you want n8n (like ${BLUE}n8n${NC})"
echo ""

read -p "Enter your domain name (e.g., example.com): " DOMAIN_NAME
read -p "Enter your subdomain for n8n (e.g., n8n): " SUBDOMAIN

# Confirm the full address
echo ""
echo -e "Your n8n will be available at: ${GREEN}https://${SUBDOMAIN}.${DOMAIN_NAME}${NC}"
echo ""
read -p "Is this correct? (y/n): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled. Please run the script again.${NC}"
    exit 0
fi

# Set timezone to UTC
TIMEZONE="UTC"

# Create .env file
show_message "Saving your settings"
cat > .env << EOL
# Domain and subdomain to use
DOMAIN_NAME=${DOMAIN_NAME}
SUBDOMAIN=${SUBDOMAIN}

# Timezone to use
GENERIC_TIMEZONE=${TIMEZONE}

# Folder where all data should be saved
DATA_FOLDER=$(pwd)
EOL

# Docker installation check with progress indicator
show_message "Checking if your system is ready"

# Docker check
echo -n "Checking for Docker... "
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Not found${NC}"
    echo "Installing Docker (this may take a few minutes)..."
    apt-get update &>/dev/null
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common &>/dev/null
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - &>/dev/null
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" &>/dev/null
    apt-get update &>/dev/null
    apt-get install -y docker-ce docker-ce-cli containerd.io &>/dev/null
    echo -e "${GREEN}Done!${NC}"
else
    echo -e "${GREEN}Found!${NC}"
fi

# Docker Compose check
echo -n "Checking for Docker Compose... "
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Not found${NC}"
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose &>/dev/null
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo -e "${GREEN}Done!${NC}"
else
    echo -e "${GREEN}Found!${NC}"
fi

# Setup firewall
show_message "Setting up security"
echo "Opening necessary ports on your firewall..."
apt-get install -y ufw &>/dev/null
ufw allow 22 &>/dev/null
ufw allow 80 &>/dev/null
ufw allow 443 &>/dev/null
echo -e "${GREEN}Security settings applied!${NC}"

# Create Docker volumes
show_message "Creating storage areas"
docker volume create caddy_data &>/dev/null
docker volume create n8n_data &>/dev/null

# Ensure required directories exist
mkdir -p caddy_config
mkdir -p local_files

# Configure Caddy with SSL
show_message "Setting up secure access"
cat > caddy_config/Caddyfile << EOL
${SUBDOMAIN}.${DOMAIN_NAME} {
    tls /config/ssl/cert.pem /config/ssl/key.key
    reverse_proxy n8n:5678 {
        flush_interval -1
    }
}
EOL

# Copy SSL certificates to Caddy config
mkdir -p caddy_config/ssl
cp ssl/cert.pem caddy_config/ssl/
cp ssl/key.key caddy_config/ssl/

# Set permissions
chmod -R 755 caddy_config
chmod -R 755 local_files

# Start containers
show_message "Starting n8n"
echo "This may take a minute..."
docker-compose up -d

# Display success message
show_message "Success! Your n8n is ready"
echo -e "Your n8n is now running at: ${GREEN}https://${SUBDOMAIN}.${DOMAIN_NAME}${NC}"
echo ""
echo -e "Helpful commands:"
echo -e "• To stop n8n:    ${BLUE}docker-compose stop${NC}"
echo -e "• To start n8n:   ${BLUE}docker-compose start${NC}"
echo -e "• To check logs:  ${BLUE}docker-compose logs -f${NC}"
echo ""
echo -e "${GREEN}Thank you for installing n8n!${NC}"
