version 1.0

workflow main {
	input {
		String download_docker = "us-central1-docker.pkg.dev/lage-genoppi/genoppi/taplin-download:2026.05.04"
		String msconvert_docker = "proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.26121-ed8dc8a"
		String username
		String search_id
		String sample_id
		String destination
	}

	call download_taplin_data {
		input:
			download_docker = download_docker,
			username = username,
			search_id = search_id,
			sample_id = sample_id,
			destination = destination
	}

	call check_raw_file {
		input:
			msconvert_docker = msconvert_docker,
			sample_id = sample_id,
			raw_file = download_taplin_data.raw_file
	}

	output {
		String raw_link = download_taplin_data.raw_link
		String mzxml_link = download_taplin_data.mzxml_link
		String mzid_link = download_taplin_data.mzid_link
		String sequest_link = download_taplin_data.sequest_link
		String raw_check = check_raw_file.raw_check
	}
}

task download_taplin_data {
	input {
		String download_docker
		String username                        
		String search_id                        
		String sample_id                        
		String destination                     
	}

	command <<<
		echo "### retrieve Taplin server password from Secret Manager"
		password=$(gcloud secrets versions access latest \
		--secret="taplin-~{username}" --project="lage-genoppi")

		echo "### run Python download script"
		python /usr/local/src/downloadTaplinData.py \
		"~{username}" \
		"${password}" \
		"~{search_id}" \
		"~{sample_id}"

		echo "### upload raw file to destination bucket"
		raw_file="~{username}/~{sample_id}/~{sample_id}.raw"
		raw_link="NA"
		if [ -f "${raw_file}" ]; then
			raw_link="~{destination}/${raw_file}"
			gcloud storage cp "${raw_file}" "${raw_link}"
			echo "Uploaded: ${raw_link}"
		else
			echo "Missing: ${raw_file}"
		fi

		echo "### check text files for corruption then upload to destination bucket"
		mzxml_file="~{username}/~{sample_id}/~{sample_id}.mzXML"
		mzxml_link="NA"
		if [ -f "${mzxml_file}" ] && ! grep -Paq "\x00" "${mzxml_file}"; then
			mzxml_link="~{destination}/${mzxml_file}"
			gcloud storage cp "${mzxml_file}" "${mzxml_link}"
			echo "Uploaded: ${mzxml_link}"
		else
			echo "Missing or corrupted: ${mzxml_file}"
		fi
	
		mzid_file="~{username}/~{sample_id}/~{search_id}_~{sample_id}.mzid"
		mzid_link="NA"
		if [ -f "${mzid_file}" ] && ! grep -Paq "\x00" "${mzid_file}"; then
			mzid_link="~{destination}/${mzid_file}"
			gcloud storage cp "${mzid_file}" "${mzid_link}"
			echo "Uploaded: ${mzid_link}"
		else
			echo "Missing or corrupted: ${mzid_file}"
		fi

		sequest_file="~{username}/~{sample_id}/~{search_id}.sequest.params"
		sequest_link="NA"
		if [ -f "${sequest_file}" ] && ! grep -Paq "\x00" "${sequest_file}"; then
			sequest_link="~{destination}/${sequest_file}"
			gcloud storage cp "${sequest_file}" "${sequest_link}"
			echo "Uploaded: ${sequest_link}"
		else
			echo "Missing or corrupted: ${sequest_file}"
		fi

		echo "${raw_link}" > raw.txt
		echo "${mzxml_link}" > mzxml.txt
		echo "${mzid_link}" > mzid.txt
		echo "${sequest_link}" > sequest.txt
	
	>>>

	output {
		String raw_link = read_string("raw.txt")
		String mzxml_link = read_string("mzxml.txt")
		String mzid_link = read_string("mzid.txt")
		String sequest_link = read_string("sequest.txt")
		
		# intermediate file
		File raw_file = "~{username}/~{sample_id}/~{sample_id}.raw"
	}

	runtime {
		docker: "~{download_docker}"
		memory: "2 GB"
		cpu: 1
		preemptible: 1
	}
}

task check_raw_file {
	input {
		String msconvert_docker
		String sample_id
		File raw_file
	}

	command <<<
	
		echo "### run msconvert on raw file"
		wine msconvert "~{sample_id}.raw" > "~{sample_id}.msconvert.log"
		
		echo "### confirm raw file integrity"
		if grep "writing output file" "~{sample_id}.msconvert.log"; then	
			raw_check="PASS"
		else
			raw_check="FAIL"
		fi	
	
		echo "${raw_check}" > check.txt
	>>>

	output {
		String raw_check = read_string("check.txt")
	}
	
	runtime {
		docker: "~{msconvert_docker}"
		memory: "2 GB"
		cpu: 1
		preemptible: 1
	}
}

