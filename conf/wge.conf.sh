# This is the WGE localisation file for server installations
# All installations require this file to be configured appropriately
# in order to run WGE successfully.

export WGE_BASE=/www/user

# The database profile
# You must have a PostgreSQL database installed with the WGE schema and relevant
# data loaded. Youj don't need every table to be populate dto use WGE.
# The details are documented on the WGE GitHub repo and elsewhere.
# This line is NOT the name of the WGE database, it is the key that accesss a hash of data
# that will enable the web application (WebApp) to connect to the PostgreSQL instance

export WGE_CONFIGURE_DB=MY_DB_PROFILE

# An Off Target Server (GitHub:CRISPR-Analyser)  must be installed and running to use many features
# of WGE related to CRISPR off targets.

export WGE_CONFIGURE_OTS_URL="http://localhost:8080/"

# Now for the location of the core files for the WGE WebApp
# All the relevant repositories must be installed under one directory - except WGE itself
# which may be installed in another location (primarily for development).

export WGE_SHARED=$WGE_BASE/git-checkout

# The location of the root of the WGE package

export WGE_DEV_ROOT=$WGE_SHARED/WGE

# There may be an issue with Ensembl timeouts resulting in poor performance, if so set this variable to 1
# In development mode, always set this to 1
# In production mode, running under FCGI and Apache a timeout from Ensembl will result in that FCGI thread
# being terminated and the perofrmance of WGE overall will be maintained.
# Use a local installation of Ensembl to avoid the timeout issue from the public server.

export WGE_NO_TIMEOUT=1
#unset WGE_NO_TIMEOUT

# The default webapp server port is 3000, the fastcgi in default configuration expects 3031...
# However, you must use whichever port is on you factcgi file, if you are setting up FCGI support

export WGE_WEBAPP_SERVER_PORT=8002
export WGE_LIVE_WEBAPP_SERVER_PORT=8000

# You can run from the command line with
# wge webapp
# but this will not support many users, instead we recommend fastCGI.
# There are other options here but we only support FCGI.

export WGE_CONFIGURE_FCGI=$WGE_PRODUCTION/conf/fastcgi.yaml
export WGE_FCGI_SCRIPT_PATH=$WGE_PRODUCTION/bin/wge_fastcgi.pl
export WGE_FCGI_PROC=8
export WGE_FCGI_PID_FILE=/var/tmp/wge/run/fastcgi.pid

# Apache configration
export WGE_APACHE_PORT=8001
export WGE_PRODUCTION=/opt/wge/live
export WGE_FCGI_HOST=localhost
export WGE_FCGI_PORT=$WGE_LIVE_WEBAPP_SERVER_PORT
export WGE_SERVER_EMAIL=wge_admin@local

# Ensembl server location
export WGE_ENSEMBL_HOST=myensembldb.local
export WGE_ENSEMBL_USER=ensro

# WGE_OPT is where the local perl modules and other ancillary tools live

export WGE_OPT=/www/user/WGE/opt

# Finally, run the setup script. This configures your environment properly and give you the
# 'wge' command. From this point on you should just be able to use the 'wge' command to manage
# the WGE services, start and stop the off-target server (if it is on the same host) and so on.
 
source $WGE_DEV_ROOT/bin/wge_setup.sh
