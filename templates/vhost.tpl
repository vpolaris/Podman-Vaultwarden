<VirtualHost *:80>
    ServerName ${DOMAIN}:80
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName  ${DOMAIN}:${HTTPS}
    ServerAlias  ${DOMAIN}
    ServerAdmin admin@${DOMAIN}

    SSLCertificateFile /etc/pki/tls/certs/vaultwarden.pem
    SSLCertificateKeyFile /etc/pki/tls/private/vaultwarden.key
    SSLCACertificateFile /home/admin/.ssl/CA-Vaultwarden.pem

    Protocols h2 http/1.1

    ErrorLog /var/lib/vaultwarden/logs/httpd/error_log
    CustomLog /var/lib/vaultwarden/logs/httpd/access_log combined

    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /notifications/hub(.*) ws://127.0.0.1:3012/ [P,L]
    ProxyPass / http://127.0.0.1:8000/

    ProxyPreserveHost On
    ProxyRequests Off
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s
</VirtualHost>