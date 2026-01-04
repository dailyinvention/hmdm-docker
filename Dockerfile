FROM ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    openjdk-11-jre-headless \
    nginx \
    gettext-base \
    aapt \
    postgresql-client \
    vim \
    certbot \
    unzip \
    net-tools \
    expect \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Tomcat 9 at /var/lib/tomcat9 (standard Ubuntu location) so HMDM installer can find it
RUN mkdir -p /var/lib/tomcat9 && \
    cd /tmp && \
    curl -s https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz -o tomcat.tar.gz && \
    tar -xzf tomcat.tar.gz -C /var/lib/tomcat9 --strip-components=1 && \
    rm tomcat.tar.gz && \
    # Remove the default Tomcat ROOT webapp so HMDM can be deployed fresh
    rm -rf /var/lib/tomcat9/webapps/ROOT && \
    chmod +x /var/lib/tomcat9/bin/*.sh && \
    # Create symlinks for convenience
    ln -s /var/lib/tomcat9 /opt/tomcat && \
    ln -s /var/lib/tomcat9 /usr/share/tomcat9

# Remove default nginx config
RUN rm /etc/nginx/sites-enabled/default

# Copy headwind config template
COPY headwind.conf /etc/nginx/sites-available/headwind.conf.template

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Copy HMDM installer (pre-downloaded to avoid network issues during startup)
COPY hmdm-installer /hmdm-pre-downloaded

# Copy HMDM installation script
COPY hmdm-install.sh /hmdm-install.sh
RUN chmod +x /hmdm-install.sh

# Copy automated expect script for non-interactive installation
COPY hmdm-install-automated.expect /hmdm-install-automated.expect
RUN chmod +x /hmdm-install-automated.expect

# Create log directories
RUN mkdir -p /var/log/nginx

# Expose ports
EXPOSE 80 443 8080

# Use the entrypoint script to substitute variables and start services
ENTRYPOINT ["/docker-entrypoint.sh"]
