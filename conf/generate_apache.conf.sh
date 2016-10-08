#! /bin/bash
sed -e 's?#WGE_APACHE_PORT?'"$WGE_APACHE_PORT"'?g' < wge_apache.conf.tpl > wge_apache.conf
sed -i -e 's?#WGE_FCGI_HOST?'"$WGE_FCGI_HOST"'?g' wge_apache.conf
sed -i -e  's?#WGE_FCGI_PORT?'"$WGE_FCGI_PORT"'?g' wge_apache.conf
sed -i -e 's?#WGE_PRODUCTION?'"$WGE_PRODUCTION"'?g' wge_apache.conf
sed -i -e 's?#WGE_DEV_ROOT?'"$WGE_DEV_ROOT"'?g' wge_apache.conf
sed -i -e 's?#WGE_SERVER_EMAIL?'"$WGE_SERVER_EMAIL"'?g' wge_apache.conf
