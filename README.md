# mira

## mira is an integrated content management framework for create multiple websites

you can create your blogs, photoblogs, image galleries, podcasts, books, portfolio, docs, manuals, projects pages and... in mira's floors. each floor is a separate website which can have its own config, template and fields or use main floor settings.

### simple

No need databases, just static content flies and a template body. mira performs all other tasks

### modern

Write your contetnt's body whatever you like, Markdown, Textile, BBcode, HTML or just simple texts.

### flexible

no limit for make archive lists like categories, tags, seassions, chapters and... or single fields like title, sub title, thumbs and... just keep dreaming about what you need, mira will make them


## install

#### perl shell

```
$ perl -MCPAN -e shell
> install Mira
```

#### cpanm

	cpanm Mira

## start

```
mkdir mira_Site_name  
cd mira_Site_name  
mira init  
```

## usage

### new post

```
  mira new -t "YOUR POST TITLE" -f "FLOOR_NAME"
```

this command make your content file in: content/FLOOR_NAME/yy-mm-dd-YOUR_POST_TITLE.pen  
in header this file have your fields structures, from structure/FLOOR_NAME + utid, title, date...

NOTE: never edit utid

### build

```
  mira build
```

mira make your sites in public directory, if your floor have them config file, mira use it for make your floor, and if no config file mira make it in public/FLOOR_NAME by default configs stored in main config.yml

### preview

```
  mira view [--host 127.0.0.1] [--port 5000]
```

a simple static file server based on your public directory

