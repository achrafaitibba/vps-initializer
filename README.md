# VPS Setup & Deployment Project

This project provides an automated setup pipeline for deploying and configuring a VPS (Virtual Private Server) with basic security measures, LETSENCRYPT to enable SSL, and NGINX deployment.

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── pipeline.yml
├── vps_setup.sh
├── advanced_setup.sh (optional)
└── docker-compose.nginx.yml
```

## Quick Start

### Using GitHub Actions Pipeline

1. Fork this repository
2. Add the following secrets to your GitHub repository:
    - `ROOT_PASSWORD`: Your VPS root password
    - `VPS_IP`: Your VPS IP address

   To add secrets:
    1. Go to your repository settings
    2. Navigate to Secrets and Variables > Actions
    3. Click "New repository secret"
    4. Add each secret with its corresponding value

3. Push changes to the `main` branch to trigger the pipeline

### Manual Setup

You can run the setup without the pipeline by executing the scripts directly on your VPS:

```bash
# Basic setup
wget https://raw.githubusercontent.com/your-username/vps-setup/main/vps_setup.sh
chmod +x vps_setup.sh
./vps_setup.sh

# Optional advanced setup
wget https://raw.githubusercontent.com/your-username/vps-setup/main/advanced_setup.sh
chmod +x advanced_setup.sh
./advanced_setup.sh
```

Or
```bash

# Copy and run basic setup
scp vps_setup.sh root@your_vps_ip:~
ssh root@your_vps_ip "chmod +x vps_setup.sh && ./vps_setup.sh"

# For advanced setup
scp advanced_script.sh root@your_vps_ip:~
ssh root@your_vps_ip "chmod +x advanced_script.sh && ./advanced_script.sh"

# Deploy services
scp docker-compose.nginx.yml root@your_vps_ip:~
ssh root@your_vps_ip "docker compose -f docker-compose.nginx.yml up -d"
```
### Docker Compose Manual Deployment

To deploy NGINX manually:

```bash
wget https://raw.githubusercontent.com/your-username/vps-setup/main/docker-compose.nginx.yml
docker compose -f docker-compose.nginx.yml up -d
```
---
## Domain and SSL Configuration

### Prerequisites
1. Own a domain name
2. Access to your domain provider's DNS settings

### Setup Steps

1. Create an A Record:
    - Log into your domain provider's dashboard
    - Add a new A record pointing to your VPS IP address:
        - Type: A
        - Name: @ (for root domain) or subdomain (e.g., 'test' for test.yourdomain.com)
        - Value: Your VPS IP address
        - TTL: 3600 (or as preferred)

2. Configure your Docker Service:
   Update your service configuration in your app docker-compose.yml to include SSL support:
#### Simply add to your service 
```
environment:
      VIRTUAL_HOST: test.yourdomain.com
      LETSENCRYPT_HOST: test.yourdomain.com
```
Example:
```yaml
services:
  service-name:
    image: ....
    environment:
      VIRTUAL_HOST: test.yourdomain.com
      LETSENCRYPT_HOST: test.yourdomain.com
      LETSENCRYPT_EMAIL: ${EMAIL} # Optional hh
    networks:
      - nginx-proxy-network
networks:
  nginx-proxy-network:
    external: true
```

Key points:
- Replace `test.yourdomain.com` with your actual domain/subdomain
- Ensure the service is connected to `nginx-proxy-network`
- The `VIRTUAL_HOST` and `LETSENCRYPT_HOST` environment variables must match your domain
- SSL certificates will be automatically generated through Let's Encrypt

3. Apply Configuration:
```bash
docker compose up -d
```

4. Verify SSL:
    - Wait a few minutes for SSL certificate generation
    - Visit your domain through HTTPS
    - Check certificate validity in your browser
---
## Scripts Overview

### vps_setup.sh (Basic Setup)
- Updates system packages
- Installs essential tools
- Configures basic firewall rules
- Sets up Docker and Docker Compose
- Implements basic security measures

### advanced_setup.sh (Optional but Recommended)
- Implements additional security measures
- Configures fail2ban
- Sets up log monitoring
- Hardens SSH configuration
- Creates non-root user with sudo privileges

⚠️ **Note**: The script will only run once. After running, be carefull with the following:
- Disable root SSH access
- Change SSH port from default (22)
- Set up SSH key authentication
- Disable password authentication

## Pipeline Workflow

The pipeline consists of two main jobs:

1. `server-setup`: Configures the VPS with basic requirements
2. `deploy-nginx`: Deploys NGINX using Docker Compose

The pipeline triggers on pushes to `main` branch when changes are made to:
- `docker-compose.nginx.yml`
- `.github/workflows/pipeline.yml`
- `vps_setup.sh`

## Security Recommendations

1. After initial setup:
    - Change default SSH port
    - Disable root SSH access
    - Enable SSH key authentication
    - Disable password authentication
    - Configure and enable fail2ban
    - Set up proper firewall rules

2. For production environments:
    - Use secrets management service
    - Implement regular security updates
    - Set up monitoring and logging
    - Use HTTPS with valid certificates
    - Regularly audit access logs


## Contributing
> ⚠️ **Warning:** My code sucks, feel free to make a PR hh

1. Fork the repository
2. Create a feature branch
3. Submit a pull request
---

## Links
[LinkedIn](https://www.linkedin.com/in/achrafaitibba)

[My Website](https://www.achrafaitibba.com)

[Twitter](https://www.twitter.com/achrafaitibba)