# This is the WGE localisation file for client installations
# All installations require this file to be configured appropriately
# in order to run WGE successfully.

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

export WGE_SHARED=/www/user/git-checkout

# The location of the root of the WGE package

export WGE_DEV_ROOT=$WGE_SHARED/WGE

# There may be an issue with Ensembl timeouts resulting in poor performance, if so set this variable to 1

export WGE_NO_TIMEOUT=1

# The default webapp server port is 3000, the fastcgi expects 3031...

export WGE_WEBAPP_SERVER_PORT=3031

# You can run from the command line with
# wge webapp
# but this will not support many users, instead we recommend fastCGI.
# There are other options here but we only support FCGI.

export WGE_CONFIGURE_FCGI=$WGE_DEV_ROOT/conf/fastcgi.yaml

# WGE_OPT is where the local perl modules and other ancillary tools live

# Ensembl server location
export WGE_ENSEMBL_HOST=ensembldb.internal.sanger.ac.uk
export WGE_ENSEMBL_USER=ensro

export WGE_OPT=/www/user/WGE/opt

# Finally, run the setup script. This configures your environment properly and give you the
# 'wge' command. From this point on you should just be able to use the 'wge' command to manage
# the WGE services, start and stop the off-target server (if it is on the same host) and so on.
 
source $WGE_DEV_ROOT/bin/wge_setup.sh
