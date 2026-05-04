version 1.0

workflow main {
	input {
		String download_image = "us-central1-docker.pkg.dev/lage-genoppi/genoppi/taplin-download:2026.05.04"
		String msconvert_image = "proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.26121-ed8dc8a"
		String username
		String search_id
		String sample_id
		String final_bucket
	}

	call download_taplin_data {
		input:
			download_image = download_image,
			username = username,
			search_id = search_id,
			sample_id = sample_id,
			final_bucket = final_bucket
	}

	call check_raw_file {
		input:
			msconvert_image = msconvert_image,
			sample_id = sample_id
			raw_link = raw_link
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
		String download_image
		String username                        
		String search_id                        
		String sample_id                        
		String final_bucket                     
	}

	command <<<
		echo "### retrieve Taplin server password from Secret Manager"
		password=$(gcloud secrets versions access latest \
		--secret="taplin-{username}" --project="lage-genoppi")

		echo "### run Python download script"
		python downloadTaplinData.py \
		"~{username}" \
		"~{password}" \
		"~{search_id}" \
		"~{sample_id}"

		echo "### upload raw file to final bucket"
		raw_file="~{username}/~{sample_id}/~{sample_id}.raw"
		raw_link="NA"
		if [ -f "~{raw_file}" ]; then
			raw_link="~{final_bucket}/~{raw_file}"
			gcloud storage cp "~{raw_file}" "~{raw_link}"
			#rm "~{raw_file}"
			echo "Uploaded: ~{raw_link}"
		fi

		echo "### check text files for corruption then upload to final bucket"
		mzxml_file="~{username}/~{sample_id}/~{sample_id}.mzXML"
		mzxml_link="NA"
		if [ -f "~{mzxml_file}" ] && [ ! grep -Paq "\x00" "~{mzxml_file}" ]; then
			mzxml_link="~{final_bucket}/~{mzxml_file}"
			gcloud storage cp "~{mzxml_file}" "~{mzxml_link}"
			#rm "~{mzxml_file}"
			echo "Uploaded: ~{mzxml_link}"
		fi
	
		mzid_file="~{username}/~{sample_id}/~{search_id}_~{sample_id}.mzid"
		mzid_link="NA"
		if [ -f "~{mzid_file}" ] && [ ! grep -Paq "\x00" "~{mzid_file}" ]; then
			mzid_link="~{final_bucket}/~{mzid_file}"
			gcloud storage cp "~{mzid_file}" "~{mzid_link}"
			#rm "~{mzid_file}" 
			echo "Uploaded: ~{mzid_link}"
		fi

		sequest_file="~{username}/~{sample_id}/~{search_id}.sequest.params"
		sequest_link="NA"
		if [ -f "~{sequest_file}" ] && [ ! grep -Paq "\x00" "~{sequest_file}" ]; then
			sequest_link="~{final_bucket}/~{sequest_file}"
			gcloud storage cp "~{sequest_file}" "~{sequest_link}"
			#rm "~{sequest_file}"
			echo "Uploaded: ~{sequest_link}"
		fi	
	>>>

	output {
		String raw_link = "~{raw_link}"
		String mzxml_link = "~{mzxml_link}"
		String mzid_link = "~{mzid_link}"
		String sequest_link = "~{sequest_link}"
	}

	runtime {
		docker: "~{download_image}"
		memory: "2 GB"
		cpu: 1
		preemptible: 1
	}
}

task check_raw_file {
	input {
		String msconvert_image
		String sample_id
		String raw_link
	}

	command <<<
		
		echo "### copy raw file to working directory $PWD"
		gcloud storage cp ~{raw_link} $PWD

		echo "### run msconvert"
		wine msconvert "$PWD/~{sample_id}.raw" > "~{sample_id}.msconvert.log"
		
		echo "### confirm raw file integrity"
		if grep -q "writing output file"; then	
			raw_check="PASS"
		else
			raw_check="FAIL"
		fi	
	>>>

	output {
		String raw_check = "~{raw_check}"
	}
	
	runtime {
		docker: "~{msconvert_image}
		memory: "2 GB"
		cpu: 1
		preemptible: 1
	}
}

