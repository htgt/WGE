export W2I_STRING=WGE-Information
export W2W_STRING=WGE-Warning
export W2E_STRING=WGE-Error
export WGE_DEBUG_DEFINITION="perl -d"

function wge {
    case $1 in
        live)
            wge_live
            ;;
        dev)
            wge_dev
            ;;
        show)
            wge_show
            ;;
        webapp)
            wge_webapp
            ;;
        debug)
            lims2_webapp_debug
            ;;
        local)
            wge_local
            ;;
        farm3)
            wge_farm3
            ;;
        'pg9.3')
            wge_pg9.3
            ;;
        cpanm)
            wge_cpanm $2
            ;;
        force)
            wge_force $2
            ;;
        *)
            printf "Unknown WGE command\n"
            wge_usage
    esac
}

function wge_usage {

    cat << END_USAGE
Usage: wge [command] [option [ ... ]]

commands:
    live:   use the live database defined in dbconnect
    dev:    use the dev database defined in dbconnect
    show:   list useful variables nicely formatted
    webapp: start the wge webapp on the default port
    debug:  start the webapp in perl debugging module
    local:  set up a local WGE environment
    farm3:  set up to run off-target scripts on farm3

END_USAGE
}

function wge_webapp {
    if [[  "$1"   ]] ; then
        WGE_PORT=$1 
    elif [[ "$WGE_WEBAPP_SERVER_PORT"  ]] ; then
        WGE_PORT=$WGE_WEBAPP_SERVER_PORT
    else
        WGE=3000
    fi
    printf "starting WGE webapp on port $WGE_PORT";
    if [[ "$WGE_WEBAPP_SERVER_OPTIONS" ]] ; then
        printf " with options $WGE_WEBAPP_SERVER_OPTIONS";
    fi
    printf "\n\n"
    printf "$W2I_STRING: $WGE_DEBUG_COMMAND $WGE_DEV_ROOT/script/wge_server.pl -p $WGE_PORT $WGE_WEBAPP_SERVER_OPTIONS\n"
    $WGE_DEBUG_COMMAND $WGE_DEV_ROOT/script/wge_server.pl -p $WGE_PORT $WGE_WEBAPP_SERVER_OPTIONS
}

function wge_webapp_debug {
    WGE_DEBUG_COMMAND=$WGE_DEBUG_DEFINITION
    wge_webapp $1
    unset WGE_DEBUG_COMMAND
}

function wge_live {
    export WGE_DB=WGE_LIVE
}

function wge_dev {
    export WGE_DB=WGE_BUILD_DB
}

function check_and_set {
    if [[ ! -f $2 ]] ; then
        printf "$W2W_STRING: $2 does not exist but you are setting $1 to its location\n"
    fi
    export $1=$2
}

function check_and_set_dir {
    if [[ ! -d $2 ]] ; then
        printf "$W2W_STRING: directory $2 does not exist but you are setting $1 to its location\n"
    fi
    export $1=$2
}

function wge_cpanm {
    if [[ "$1" ]] ; then
        cpanm -l $WGE_OPT/perl5 $1
        echo $1 >> $WGE_OPT/perl_depend.log
    else
        printf "$W2E_STRING: no module specified: wge_cpanm <module>\n"
    fi
}

function wge_force {
    if [[ "$1" ]] ; then
        cpanm -l $WGE_OPT/perl5 --force $1
        echo $1 >> $WGE_OPT/perl_depend.log
    else
        printf "$W2E_STRING: no module specified: wge_cpanm <module>\n"
    fi
}

function wge_pg9.3 {
    check_and_set PSQL_EXE $WGE_OPT/postgres/9.3.4/bin/psql
    check_and_set PG_DUMP_EXE $WGE_OPT/postgres/9.3.4/bin/pg_dump
    check_and_set PG_RESTORE_EXE $WGE_OPT/postgres/9.3.4/bin/pg_restore
}

function wge_psql {
    $PSQL_EXE
}

function wge_pg_dump {
    $PG_DUMP_EXE
}

function wge_pg_restore {
    $PG_RERTORE_EXE
}

function perl5lib_prepend ()
{
    test -n "$1" || {
        warn "COMPONENT not specified";
        return 1
    };
    export PERL5LIB=$(perl -le "print join ':', '$1', grep { length and \$_ ne '$1' } split ':', \$ENV{PERL5LIB}")
}

function wge_show {
cat << END
WGE useful environment variables:

\$WGE_DEV_ROOT:                 : $WGE_DEV_ROOT
\$WGE_SHARED                    : $WGE_SHARED
\$SAVED_WGE_DEV_ROOT            : $SAVED_WGE_DEV_ROOT 
\$WGE_WEBAPP_SERVER_PORT        : $WGE_WEBAPP_SERVER_PORT
\$WGE_WEBAPP_SERVER_OPTIONS     : $WGE_WEBAPP_SERVER_OPTIONS
\$WGE_DEBUG_DEFINITION          : $WGE_DEBUG_DEFINITION
\$WGE_OPT                       : $WGE_OPT

PERL5LIB :
`perl -e 'print( join("\n", split(":", $ENV{PERL5LIB}))."\n")'`

\$PATH :
`perl -e 'print( join("\n", split(":", $ENV{PATH}))."\n")'`

\$WGE_REST_CLIENT_CONFIG        : $WGE_REST_CLIENT_CONFIG
\$WGE_DBCONNECT_CONFIG              : $WGE_DBCONNECT_CONFIG
\$WGE_SESSION_STORE                 : $WGE_SESSION_STORE
\$WGE_OAUTH_CLIENT                  : $WGE_OAUTH_CLIENT
\$WGE_GMAIL_CONFIG                  : $WGE_GMAIL_CONFIG
\$WGE_LOG4PERL_CONFIG               : $WGE_LOG4PERL_CONFIG
\$LIMS2_REST_CLIENT_CONFIG          : $LIMS2_REST_CLIENT_CONFIG
\$WGE_DB                            : $WGE_DB


END
wge_local_environment
}

function wge_ensembl_modules {

    perl5lib_prepend /software/pubseq/PerlModules/Ensembl/www_76_1/ensembl-variation/modules
    perl5lib_prepend /software/pubseq/PerlModules/Ensembl/www_76_1/ensembl/modules
    perl5lib_prepend /software/pubseq/PerlModules/Ensembl/www_76_1/ensembl-compara/module
}

function wge_lib {
    perl5lib_prepend $WGE_DEV_ROOT/lib  
}

function lims2_lib {
    perl5lib_prepend $LIMS2_DEV_ROOT/lib
}

function wge_farm3 {
    wge_local
    unset PERL5LIB

    wge_ensembl_modules
   
    perl5lib_prepend /nfs/team87/farm3_lims2_vms/software/perl/lib/perl5    
}

function wge_local {
#use lims2-common
    export LIMS2_REST_CLIENT_CONFIG=~/conf/wge/wge-rest-client.conf
    export WGE_REST_CLIENT_CONFIG=~/conf/wge/wge-rest-client.conf
    export WGE_DBCONNECT_CONFIG=~/conf/wge/wge_dbconnect.yml
    export WGE_DB=WGE_BUILD_DB
    export WGE_SESSION_STORE=/tmp/wge-devel.session.dp10
    unset LIMS2_DB
    export WGE_OAUTH_CLIENT=~/conf/wge/oauth2_client_info.json
    export WGE_GMAIL_CONFIG=~/conf/wge/wge_gmail_account.yml
    export WGE_LOG4PERL_CONFIG=/nfs/team87/farm3_lims2_vms/conf/wge.log4perl.default.conf
    export SHARED_WEBAPP_STATIC_DIR=$WGE_SHARED/WebApp-Common/shared_static
    export SHARED_WEBAPP_TT_DIR=$WGE_SHARED/WebApp-Common/shared_templates
    export WGE_SESSION_STORE=/var/tmp/wge


    wge_ensembl_modules

    lims2_lib

    wge_lib
    wge_opt
}

function wge_opt {
# Location of optional software to support admin of WGE

    export WGE_OPT=~/wge/opt
}

function wge_local_environment {
    printf "No local WGE environment defined\n"
}

if [[ -f $HOME/.wge_local ]] ; then
    printf "Sourcing local mods to wge environment\n"
    source $HOME/.wge_local
fi

wge_local
