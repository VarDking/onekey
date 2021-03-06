#!/bin/bash

# written by Mr.chen.

. bin/common.sh

PWD=$(pwd)
TMP_DIR="$PWD/tmp"
PACKAGE_DIR="$PWD/packages"
REDIS_RELEASES_URL="http://download.redis.io/releases/"

DEV_PRFIX=${DEV_PRFIX-"/usr/opt/dep_env"}

assure_dir $TMP_DIR $PACKAGE_DIR $DEV_PRFIX

show_versions(){
    for version in $@
    do
        log_info_cyan $version
    done
}

# ASC
redis_versions()
{
    local versions=$(curl $REDIS_RELEASES_URL 2> /dev/null \
          | egrep "</a>" \
          | egrep -o "redis-([0-9\w\.])+\.tar.gz" \
          | egrep -o "([0-9]+\.)+[0-9]+" \
          | sort -u -k 1,1n -k 2,2n -k 3,3n -t . \
          )
    echo $versions
}

show_redis_versions()
{
    show_versions $(redis_versions)
}

latest_redis_version()
{
    local versions=($(redis_versions))
    echo ${versions[-1]}
}

redis_path(){
    if [ -z $1 ];then
        log_error "version is required"
    fi
}

download_redis(){
   local version=$1

   if [ -z $version ];then
       version="stable"
       log_warn "no version specified, default value is \"stable\""
   fi
  
   local file_name="redis-${version}.tar.gz"
   local temp_file_path="${TMP_DIR}/${file_name}"
   local local_file_path="${PACKAGE_DIR}/${file_name}"
   local remote_file_path="${REDIS_RELEASES_URL}${file_name}"

   log_info "redis file is ${file_name}"

   if [ -f ${temp_file_path} ];then
       rm -f ${temp_file_path}
   fi

   if [ -f ${local_file_path} ];then
        log_info "redis package exist"
   else
        log_info "downloading redis package..."
        wget -c -O ${temp_file_path} $remote_file_path
        mv ${temp_file_path} ${local_file_path}
        log_info "download complete"
   fi 
}

#start on boot
install_service(){
    local port=$1;
    if [ -n "${port}" ];then
        log_error "redis port is required!"
    fi

    if command -v chkconfig >/dev/null 2>&1; then
        chkconfig --add redis_${port} 
        log_info "add redis chkconfig successfully!"
        chkconfig --level 345 redis_${port} on 
        log_info "set redis runlevels 345 successfully!"
    elif command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d redis_${port} defaults 
        log_info "set redis update-rc.d successfully"
    else
        log_error "can not set start on boot!"
    fi
}

#start service
start_redis_service(){
    /etc/init.d/redis_$1 start \
    && log_info "start redis service successfully!"
}

#test installed 
test_redis(){
    if command -v $1 &> /dev/null; then
        log_info "test: $1 has been intalled"
    else 
        log_error "test: $1 is not installed"
    fi
}

#make and install
install_redis(){
    local port=6379
    local redis_path=${DEV_PRFIX}/redis    
  
    local version=${1-stable}
    local file_dir="redis-${version}"
    local file_name="redis-${version}.tar.gz"

    download_redis ${version} 
    
    cd "${PACKAGE_DIR}"
    log_info "decompressing ......"
    tar -xzvf $file_name
    cd "${PACKAGE_DIR}/${file_dir}"
     
    log_info "redis make and test ....."
    make && make test && make install
    
    test_redis redis-cli
    test_redis redis-server
}
