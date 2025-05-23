# Vagrant WordPress Stack

A complete WordPress development environment with HTTPS support using mkcert.

## Quick Start

1. **Download WordPress:**
   ```bash
   wget -q https://wordpress.org/latest.tar.gz
   tar -xzf latest.tar.gz
   cp -a wordpress app/
   rm -rf wordpress latest.tar.gz
   ```

2. **Start the VM:**
   ```bash
   vagrant up
   ```

3. **Access your site:**
   - HTTP: http://localhost:8080 or http://example.com:8080
   - HTTPS: https://localhost:8443 or https://example.com:8443
   - Adminer: http://localhost:8080/adminer

## Stack Components

- **OS**: Debian Bookworm 64-bit
- **Web Server**: Nginx
- **Database**: MariaDB
- **PHP**: PHP-FPM with WordPress extensions
- **SSL**: mkcert for local HTTPS certificates
- **Security**: UFW firewall
- **Database Management**: Adminer (lightweight phpMyAdmin alternative)

## SSL Certificates with mkcert

This stack uses [mkcert](https://github.com/FiloSottile/mkcert) to generate locally-trusted SSL certificates:

- **Auto-generated**: Certificates for `localhost`, `example.com`, `127.0.0.1`, and `::1`
- **Browser Warning**: You may see "Potential Security Risk" - click "Advanced" → "Accept Risk" for localhost
- **Location**: `/root/.local/share/mkcert/localhost+3.pem` and `localhost+3-key.pem`
- **Trust Store**: Automatically installed in system trust store

### mkcert Benefits
- No certificate warnings in browsers (when properly installed)
- Real HTTPS testing environment
- No need for complex CA setups
- Works with modern web APIs requiring HTTPS

## Database Access

- **Host**: localhost
- **Database**: wordpress
- **Username**: wpuser  
- **Password**: wppass
- **Root Password**: root

## File Structure

```
vagrant-wpstack/
├── app/wordpress/          # WordPress files (synced)
├── conf/
│   ├── wordpress.conf      # Nginx virtual host
│   └── php.ini            # PHP configuration
├── bootstrap.sh           # Provisioning script
├── Vagrantfile            # Vagrant configuration
└── README.md             # This file
```

## Useful Commands

```bash
# SSH into VM
vagrant ssh

# Restart services
vagrant ssh -c "sudo systemctl restart nginx"
vagrant ssh -c "sudo systemctl restart php8.2-fpm"

# View logs
vagrant ssh -c "sudo tail -f /var/log/nginx/error.log"

# Reprovision
vagrant reload --provision

# Stop/Start
vagrant halt
vagrant up
```

## Nginx Configuration Explained

The nginx configuration (`conf/wordpress.conf`) handles multiple services through location-based routing:

### 1. Virtual Host Setup
```nginx
server_name localhost example.com;
```
- Responds to both `localhost` and `example.com` domains
- Same configuration works for both HTTP (port 80) and HTTPS (port 443)

### 2. WordPress Routing
```nginx
root /var/www/wordpress;
location / {
    try_files $uri $uri/ /index.php?$args;
}
```

#### Understanding `try_files $uri $uri/ /index.php?$args;`

This directive is the key to WordPress pretty URLs. It works as a **three-step fallback**:

1. **`$uri`** - Try the exact file requested
   - Example: `/wp-content/themes/style.css` → Look for actual file
   - If file exists, serve it directly (images, CSS, JS)

2. **`$uri/`** - Try as a directory with index file
   - Example: `/about/` → Look for `/about/index.php` or `/about/index.html`
   - Handles directory requests

3. **`/index.php?$args`** - Final fallback to WordPress
   - Example: `/my-blog-post/` → Pass to `/index.php?$args`
   - WordPress processes the URL and finds the right content

#### Real-World Examples:

| Request URL | nginx Processing | Result |
|-------------|------------------|--------|
| `/style.css` | Step 1: File exists → serve directly | Static file served |
| `/uploads/image.jpg` | Step 1: File exists → serve directly | Image served |
| `/about-us/` | Step 1: No file → Step 2: No directory → Step 3: `/index.php` | WordPress handles route |
| `/contact` | Step 1: No file → Step 2: No directory → Step 3: `/index.php` | WordPress handles route |
| `/wp-admin/` | Step 1: No file → Step 2: Directory exists → serve index | Admin panel |

#### Why This Matters:
- **SEO-Friendly URLs**: `/my-post/` instead of `/?p=123`
- **Performance**: Static files served directly without PHP processing
- **WordPress Compatibility**: All dynamic content routed through WordPress engine

### 3. Adminer Database Manager
```nginx
location /adminer {
    alias /var/www/adminer;
    index index.php;
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /var/www/adminer/index.php;
        include fastcgi_params;
    }
}
```
- **Path Mapping**: `/adminer` URL maps to `/var/www/adminer` directory
- **Single File**: Adminer is just one PHP file (`index.php`)
- **Database Access**: Connects to MariaDB using the same PHP-FPM socket as WordPress

### 4. PHP Processing
```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    include fastcgi_params;
}
```
- **PHP-FPM Socket**: All PHP files processed through `/var/run/php/php-fpm.sock`
- **Script Path**: `SCRIPT_FILENAME` resolves actual file paths for execution
- **Security**: Prevents direct access to PHP files outside web root

### 5. Database Connection Flow

```
Browser Request → Nginx → PHP-FPM → MariaDB
     ↓              ↓         ↓         ↓
  localhost:8080  Port 80   Socket   Port 3306
```

1. **WordPress**: Uses `wp-config.php` database credentials
2. **Adminer**: Direct database connection using web interface
3. **MariaDB**: Listens on localhost:3306 with user `wpuser`/`wppass`

### 6. SSL Certificate Integration
```nginx
ssl_certificate /root/.local/share/mkcert/localhost+3.pem;
ssl_certificate_key /root/.local/share/mkcert/localhost+3-key.pem;
```
- **Multi-domain Certificate**: Covers `localhost`, `example.com`, `127.0.0.1`, `::1`
- **HTTP/2 Support**: Enabled for better performance
- **HSTS Ready**: Can be extended with security headers

### 7. Static Asset Optimization
```nginx
location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```
- **Long Expiry**: Static assets cached for 1 year
- **Performance**: Reduces server load and improves load times

## Troubleshooting

### Nginx won't start
Check certificate paths:
```bash
vagrant ssh -c "sudo nginx -t"
```

### Database connection issues
Verify database access:
```bash
vagrant ssh -c "sudo mysql -u wpuser -pwppass -e 'USE wordpress; SHOW TABLES;'"
```

### PHP errors
Check PHP-FPM status:
```bash
vagrant ssh -c "sudo systemctl status php8.2-fpm"
```