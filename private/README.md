# SSL Private Keys Directory

Place your SSL certificate private key files (.key) in this directory.

The private key specified in `SSL_CERTIFICATE_KEY_PATH` environment variable should be placed here.

Example:
- `hmdm.key` - Private key for HMDM and start documents

## Security Notes

- **IMPORTANT**: Never commit private keys to version control
- Ensure proper file permissions (600, readable only by nginx user)
- Keep backups of private keys in a secure location
- This directory is mounted as read-only to `/etc/ssl/private` in the Docker container
- This directory should be in `.gitignore` to prevent accidental commits

## Permissions

When deploying, ensure the private key file has appropriate permissions:

```bash
chmod 600 /path/to/private/hmdm.key
```
