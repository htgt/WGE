Listen $WGE_APACHE_PORT

<VirtualHost *:$WGE_APACHE_PORT>
    ServerAdmin $WGE_SERVER_EMAIL
    
    FastCGIExternalServer /wge.fcgi -host $WGE_FCGI_HOST:$WGE_PORT -idle-timeout 300 -pass-header Authorization
    
    DocumentRoot $WGE_PRODUCTION/docroots/default
    <Directory $WGE_PRODUCTION/docroots/default>
        Options FollowSymLinks -MultiViews
        Order allow,deny
        Allow from all
    </Directory>

    Alias /htgt/wge/static $WGE_DEV_ROOT/root/static
    <Directory $WGE_DEV_ROOT/root/static>
        Options -Indexes
        AllowOverride None
        Order allow,deny
        Allow from all
    </Directory>

    ErrorLog  $WGE_PRODUCTION/logs/apache/wge2/error.log
    CustomLog $WGE_PRODUCTION/logs/apache/wge2/access.log combined
</VirtualHost>

