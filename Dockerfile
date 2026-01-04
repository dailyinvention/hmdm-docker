FROM ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    gettext-base \
    aapt \
    tomcat9 \
    postgresql-client \
    vim \
    certbot \
    unzip \
    net-tools \
    wget \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Remove default nginx config
RUN rm /etc/nginx/sites-enabled/default

# Copy headwind config template
COPY headwind.conf /etc/nginx/sites-available/headwind.conf.template

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Copy Headwind MDM installation script
COPY hmdm-install.sh /hmdm-install.sh
RUN chmod +x /hmdm-install.sh

# Create log directories
RUN mkdir -p /var/log/nginx

# Expose ports
EXPOSE 80 443 8080

# Use the entrypoint script to substitute variables and start services
ENTRYPOINT ["/docker-entrypoint.sh"]
