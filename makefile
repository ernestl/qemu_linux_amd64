DEPS = build-qemu-amd64-image-initramfs.sh build-qemu-amd64-image-hda.sh
RUN_INITRAMFS = build-qemu-amd64-image-initramfs.sh
RUN_HDA = build-qemu-amd64-image-hda.sh

#------------------------------------------------
# INSTALL
#------------------------------------------------
.PHONY: install
install: # Install dependencies
	@sudo apt-get install shellcheck
	
#------------------------------------------------
# BUILD AND RUN
#------------------------------------------------
.PHONY: initramfs
initramfs: # Build AMD64 Linux initramfs filesystem and run it on Qemu
	@sudo ./$(RUN_INITRAMFS)
	
.PHONY: hda
hda: # Build AMD64 Linux initramfs filesystem and run it on Qemu
	@sudo ./$(RUN_HDA)

#------------------------------------------------
# RUN STATIC TESTS
#------------------------------------------------
.PHONY: test
test: shellcheck

.PHONY: shellcheck
shellcheck: ## Shell static checks
	@shellcheck $(DEPS)