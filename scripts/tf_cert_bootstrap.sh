#!/usr/bin/env bash

setup_env () {

    set +x

    # Binary versions to check for
    [ -f /usr/local/bootstrap/var.env ] && {
        cat /usr/local/bootstrap/var.env
        source /usr/local/bootstrap/var.env
    }

    # Configure Directories
    export conf_dir=/usr/local/bootstrap/conf/certificates
    [ ! -d $conf_dir ] && mkdir -p $conf_dir
    export CA_dir=/usr/local/bootstrap/.bootstrap/Outputs/RootCA
    [ ! -d $CA_dir ] && mkdir -p $CA_dir
    export Int_CA_dir=/usr/local/bootstrap/.bootstrap/Outputs/IntermediateCAs
    [ ! -d $Int_CA_dir ] && mkdir -p $Int_CA_dir
    export Certs_dir=/usr/local/bootstrap/.bootstrap/Outputs/Certificates
    [ ! -d $Certs_dir ] && mkdir -p $Certs_dir
    export Public_Certs_dir=/usr/local/bootstrap/.bootstrap/live/hashistack.ie
    [ ! -d $Public_Certs_dir ] && mkdir -p $Public_Certs_dir 

}

setup_env
# copy_intermediate_ca_from_tfcloud_to_host
cat ${1} > $Int_CA_dir/${2}/{$3}


    # Configure Directories
    export conf_dir=/usr/local/bootstrap/conf/certificates
    
    export CA_dir=/usr/local/bootstrap/.bootstrap/Outputs/RootCA
    [ ! -d $CA_dir ] && mkdir -p $CA_dir
    export Int_CA_dir=

    export Certs_dir=
    
    export Public_Certs_dir=
    

