##########################################################################################
# Python script to download data files for one sample from Taplin data server
# Last updated: 2026-04-27
##########################################################################################

import sys
import requests
import hashlib
from pathlib import Path

username = sys.argv[1]
password = sys.argv[2]
search_id = sys.argv[3]
sample_id = sys.argv[4]

print(f'*** username: {username}')
print(f'*** sample: {sample_id}')

# function to download file with url
def download_file(session, sample_id, file_type, url, local_filename):
	with session.get(url, stream=True) as r:
		if r.status_code==404:
			print(f'Warning: {file_type} URL not found for sample {sample_id}')
		else:
			r.raise_for_status()
			with open(local_filename, 'wb') as f:
				for chunk in r.iter_content(chunk_size=8192):
					f.write(chunk)

# set up session
session = requests.Session()
data = {'username': username, 'password': hashlib.md5(password.encode()).hexdigest()}
session.post('https://tmsf.med.harvard.edu/core/www/auth/auth-handler.php', data=data)

# make directory for sample
Path(f'{username}/{sample_id}').mkdir(parents=True,exist_ok=True)

# download all files for the sample into the sample folder
# keep naming convention used on Taplin data server
raw_url = f'https://tmsf.med.harvard.edu/core/www/modules/search/download/download_raw.php?search_id={search_id}'
download_file(session, sample_id, 'raw', raw_url, f'{username}/{sample_id}/{sample_id}.raw')

mzxml_url = f'https://tmsf.med.harvard.edu/core/www/modules/export_search/download_mzxml.php?id={search_id}'
download_file(session, sample_id, 'mzXML', mzxml_url, f'{username}/{sample_id}/{sample_id}.mzXML')

mzid_url = f'https://tmsf.med.harvard.edu/core/www/modules/mzid/download/download.php?id={search_id}&format=mzXML'
download_file(session, sample_id, 'mzid', mzid_url, f'{username}/{sample_id}/{search_id}_{sample_id}.mzid')

sequest_url = f'https://tmsf.med.harvard.edu/core/www/modules/export_search/export_files_dl.php?filename=sequest.params&search_id={search_id}'
download_file(session, sample_id, 'sequest.params', sequest_url, f'{username}/{sample_id}/{search_id}.sequest.params')

print('*** TAPLIN DOWNLOAD SCRIPT COMPLETED')

