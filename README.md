# mira

## mira is an integrated content management framework for create multiple websites

#### documents: [Documents](https://miraxy.github.io/)

## install

#### perl shell


    $ perl -MCPAN -e shell
    > install Mira


#### cpanm

	cpanm Mira

## start


    mkdir mira_Site_name  
    cd mira_Site_name  
    mira init  


## usage

### new post

    mira new -t "YOUR POST TITLE" -f "FLOOR_NAME"


### build

    mira build


### preview

    mira view [--host 127.0.0.1] [--port 5000]

> a simple static file server based on your public directory

