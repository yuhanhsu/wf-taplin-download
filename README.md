# wf-taplin-download

Files for collecting MS data files from Taplin server
- Python script (downloadTaplinData.py) to login and download data from Taplin server
- Dockerfile to containerize the Python script and install dependencies (with gcloud CLI)
- cloudbuild.yaml to build and push docker image to Google Artifact Registry via Cloud Build
- taplin-download.wdl to define the workflow to be run:
	1. download and upload data to a google bucket
	2. check integrity of downloaded .raw file using msconvert (separate docker from Docker Hub)
- .dockstore.yml to sync workflow WDL to Dockstore

Terra workflow run time: ~15 minutes

