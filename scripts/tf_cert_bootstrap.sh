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
    export CA_dir=/usr/local/bootstrap/.bootstrap/Outputs/RootCA
    export Int_CA_dir=/usr/local/bootstrap/.bootstrap/Outputs/IntermediateCAs
    export Certs_dir=/usr/local/bootstrap/.bootstrap/Outputs/Certificates
    export Public_Certs_dir=/usr/local/bootstrap/.bootstrap/live/hashistack.ie 

}

setup_env
# copy_intermediate_ca_key_from_tfcloud_to_host
cat ${1} > $Int_CA_dir/${2}/{$3}



    

