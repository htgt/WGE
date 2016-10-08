Listen #WGE_APACHE_PORT

<VirtualHost *:#WGE_APACHE_PORT>
    ServerAdmin #WGE_SERVER_EMAIL
    
    FastCGIExternalServer /wge.fcgi -host #WGE_FCGI_HOST:#WGE_FCGI_PORT -idle-timeout 300 -pass-header Authorization
    
    DocumentRoot #WGE_PRODUCTION/docroots/default
    <Directory #WGE_PRODUCTION/docroots/default>
        Options FollowSymLinks -MultiViews
        Order allow,deny
        Allow from all
    </Directory>

    Alias /wge/static #WGE_PRODUCTION/WGE/root/static
    <Directory #WGE_PRODUCTION/WGE/root/static>
        Options -Indexes
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>

    ErrorLog  #WGE_PRODUCTION/logs/apache/wge2/error.log
    CustomLog #WGE_PRODUCTION/logs/apache/wge2/access.log combined
</VirtualHost>

