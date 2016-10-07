#! /bin/bash
sed -e 's?#WGE_FCGI_SCRIPT_PATH?'"$WGE_FCGI_SCRIPT_PATH"'?g' < wge_fcgi.yaml.tpl > wge_fcgi.yaml
sed -i -e 's?#WGE_FCGI_PROC?'"$WGE_FCGI_PROC"'?g' wge_apache.conf
sed -i -e  's?#WGE_PORT?'"$WGE_PORT"'?g' wge_apache.conf
sed -i -e 's?#WGE_PRODUCTION?'"$WGE_PRODUCTION"'?g' wge_apache.conf
sed -i -e 's?#WGE_DEV_ROOT?'"$WGE_DEV_ROOT"'?g' wge_apache.conf
sed -i -e 's?#WGE_SERVER_EMAIL?'"$WGE_SERVER_EMAIL"'?g' wge_apache.conf
