# SSL Certificates Directory

Place your SSL certificate files (.crt or .pem) in this directory.

The certificate specified in `SSL_CERTIFICATE_PATH` environment variable should be placed here.

Example:
- `hmdm.crt` - Combined certificate chain for HMDM and start documents

## Notes

- This directory is mounted as read-only to `/etc/ssl/certs` in the Docker container
- Ensure proper file permissions (readable by the nginx user)
- Do not commit actual certificates to version control
- This directory is included in `.gitignore` to prevent accidental commits
