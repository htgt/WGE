#! /bin/bash
sed -e 's?#WGE_FCGI_SCRIPT_PATH?'"$WGE_FCGI_SCRIPT_PATH"'?g' < fastcgi.yaml.tpl > fastcgi.yaml
sed -i -e 's?#WGE_FCGI_PROC?'"$WGE_FCGI_PROC"'?g' fastcgi.yaml
sed -i -e 's?#WGE_FCGI_PID_FILE?'"$WGE_FCGI_PID_FILE"'?g' fastcgi.yaml
sed -i -e 's?#WGE_FCGI_HOST?'"$WGE_FCGI_HOST"'?g' fastcgi.yaml
sed -i -e 's?#WGE_FCGI_PORT?'"$WGE_FCGI_PORT"'?g' fastcgi.yaml
