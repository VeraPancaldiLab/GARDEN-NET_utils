FROM r-base:3.6.0

RUN apt update

# ./layout_enricher/layout_enricher requirements

RUN apt install -y curl gnupg

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -

RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt update && apt install -y yarn

# ./backend.py

RUN apt install -y jq python3-dev python3-pip python3-gdbm parallel

RUN pip3 install flask flask-cors gunicorn celery[redis]

# ./search_query.R

RUN apt install -y curl libssl-dev libxml2-dev libcurl4-openssl-dev

RUN Rscript -e 'install.packages(c("tibble", "stringr", "readr",  "dplyr", "rjson", "igraph", "optparse", "devtools", "data.table"))'

RUN Rscript -e 'install.packages("BiocManager")'

RUN Rscript -e 'BiocManager::install()'

RUN Rscript -e 'BiocManager::install("GenomicRanges")'

# To force rebuild the image at this point do

# docker build --build-arg UPDATE_CHASER_VERSION=TRUE -t garden-net_utils-upload_features .

ARG UPDATE_CHASER_VERSION=FALSE

RUN Rscript -e 'library(devtools);install_bitbucket("eraineri/chaser")'

