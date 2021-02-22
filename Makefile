.PHONY: combine pdf docx clean

project_name := hpc_lab

combine: generated/$(project_name).md

pdf: generated/$(project_name).pdf

docx: generated/$(project_name).docx

generated/$(project_name).md: docs mkdocs.yml
	mkdir -p generated
	mkdocscombine -d -o $@
	bash ./pandoc/remove_duplicate_title.sh $@

generated/$(project_name).docx: generated/$(project_name).md pandoc/docx.yml
	pandoc --defaults pandoc/docx.yml -s -o $@ $<

generated/$(project_name).pdf: generated/$(project_name).md pandoc/pdf.yml
	pandoc --defaults pandoc/pdf.yml -o $@ $<

clean:
	rm -rf generated
