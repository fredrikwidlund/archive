iso: image
	@./script/create-iso.sh $$(find work -type f -name archlinux*.iso)

image: work
	@./script/download-iso.sh

work:
	@mkdir -p work
