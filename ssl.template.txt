Listen ${HTTPS} https


SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog

SSLSessionCache         shmcb:/run/httpd/sslcache(512000)
SSLSessionCacheTimeout  300

SSLRandomSeed startup file:/dev/urandom  256
SSLRandomSeed connect builtin

SSLCryptoDevice builtin

Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
Header always set Referrer-Policy no-referrer

SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"

<VirtualHost _default_:${HTTPS}>


ErrorLog /var/lib/bitwarden/logs/httpd/ssl_error_log
TransferLog /var/lib/bitwarden/logs/httpd/ssl_access_log
LogLevel warn

SSLEngine on
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1

SSLHonorCipherOrder on

SSLCipherSuite PROFILE=SYSTEM
SSLProxyCipherSuite PROFILE=SYSTEM

SSLCertificateFile /etc/pki/tls/certs/localhost.crt
SSLCertificateKeyFile /etc/pki/tls/private/localhost.key


<FilesMatch "\.(cgi|shtml|phtml|php)$">
    SSLOptions +StdEnvVars
</FilesMatch>
<Directory "/var/www/cgi-bin">
    SSLOptions +StdEnvVars
</Directory>

BrowserMatch "MSIE [2-5]" \
         nokeepalive ssl-unclean-shutdown \
         downgrade-1.0 force-response-1.0

CustomLog logs/ssl_request_log \
          "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"
		  
SSLSessionTickets Off
SSLUseStapling On
</VirtualHost>
