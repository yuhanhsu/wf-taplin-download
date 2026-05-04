### Dockerfile for python, gcloud, requests, and Taplin data download script

# base image from google/cloud-sdk: https://hub.docker.com/r/google/cloud-sdk
# use alpine version that includes python executable
FROM google/cloud-sdk:alpine
LABEL maintainer="Yu-Han Hsu <yuhanhsu@broadinstitute.org>"

# prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# install requests
RUN rm /usr/lib/python3.*/EXTERNALLY-MANAGED \
	&& pip install --no-cache-dir requests

# copy Taplin data download Python script to /usr/local/src
WORKDIR /usr/local/src
COPY downloadTaplinData.py ./

