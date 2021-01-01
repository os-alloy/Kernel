# SPDX-License-Identifier: GPL-2.0
# Backward compatibility
asflags-y  += $(EXTRA_AFLAGS)
ccflags-y  += $(EXTRA_CFLAGS)
cppflags-y += $(EXTRA_CPPFLAGS)
ldflags-y  += $(EXTRA_LDFLAGS)
ifneq ($(always),)
$(warning 'always' is deprecated. Please use 'always-y' instead)
always-y   += $(always)
endif
ifneq ($(hostprogs-y),)
$(warning 'hostprogs-y' is deprecated. Please use 'hostprogs' instead)
hostprogs  += $(hostprogs-y)
endif
ifneq ($(hostprogs-m),)
$(warning 'hostprogs-m' is deprecated. Please use 'hostprogs' instead)
hostprogs  += $(hostprogs-m)
endif

# flags that take effect in current and sub directories
KBUILD_AFLAGS += $(subdir-asflags-y)
KBUILD_CFLAGS += $(subdir-ccflags-y)

# Figure out what we need to build from the various variables
# ===========================================================================

# When an object is listed to be built compiled-in and modular,
# only build the compiled-in version
obj-m := $(filter-out $(obj-y),$(obj-m))

# Libraries are always collected in one lib file.
# Filter out objects already built-in
lib-y := $(filter-out $(obj-y), $(sort $(lib-y) $(lib-m)))

# Subdirectories we need to descend into
subdir-ym := $(sort $(subdir-y) $(subdir-m) \
			$(patsubst %/,%, $(filter %/, $(obj-y) $(obj-m))))

# Handle objects in subdirs:
# - If we encounter foo/ in $(obj-y), replace it by foo/built-in.a and
#   foo/modules.order
# - If we encounter foo/ in $(obj-m), replace it by foo/modules.order
#
# Generate modules.order to determine modorder. Unfortunately, we don't have
# information about ordering between -y and -m subdirs. Just put -y's first.

ifdef need-modorder
obj-m := $(patsubst %/,%/modules.order, $(filter %/, $(obj-y)) $(obj-m))
else
obj-m := $(filter-out %/, $(obj-m))
endif

ifdef need-builtin
obj-y		:= $(patsubst %/, %/built-in.a, $(obj-y))
else
obj-y		:= $(filter-out %/, $(obj-y))
endif

# If $(foo-objs), $(foo-y), $(foo-m), or $(foo-) exists, foo.o is a composite object
multi-used-y := $(sort $(foreach m,$(obj-y), $(if $(strip $($(m:.o=-objs)) $($(m:.o=-y)) $($(m:.o=-))), $(m))))
multi-used-m := $(sort $(foreach m,$(obj-m), $(if $(strip $($(m:.o=-objs)) $($(m:.o=-y)) $($(m:.o=-m)) $($(m:.o=-))), $(m))))
multi-used   := $(multi-used-y) $(multi-used-m)

# Replace multi-part objects by their individual parts,
# including built-in.a from subdirectories
real-obj-y := $(foreach m, $(obj-y), $(if $(strip $($(m:.o=-objs)) $($(m:.o=-y)) $($(m:.o=-))),$($(m:.o=-objs)) $($(m:.o=-y)),$(m)))
real-obj-m := $(foreach m, $(obj-m), $(if $(strip $($(m:.o=-objs)) $($(m:.o=-y)) $($(m:.o=-m)) $($(m:.o=-))),$($(m:.o=-objs)) $($(m:.o=-y)) $($(m:.o=-m)),$(m)))

always-y += $(always-m)

# hostprogs-always-y += foo
# ... is a shorthand for
# hostprogs += foo
# always-y  += foo
hostprogs += $(hostprogs-always-y) $(hostprogs-always-m)
always-y += $(hostprogs-always-y) $(hostprogs-always-m)

# userprogs-always-y is likewise.
userprogs += $(userprogs-always-y) $(userprogs-always-m)
always-y += $(userprogs-always-y) $(userprogs-always-m)

# DTB
# If CONFIG_OF_ALL_DTBS is enabled, all DT blobs are built
extra-y				+= $(dtb-y)
extra-$(CONFIG_OF_ALL_DTBS)	+= $(dtb-)

ifneq ($(CHECK_DTBS),)
extra-y += $(patsubst %.dtb,%.dt.yaml, $(dtb-y))
extra-$(CONFIG_OF_ALL_DTBS) += $(patsubst %.dtb,%.dt.yaml, $(dtb-))
endif

# Add subdir path

extra-y		:= $(addprefix $(obj)/,$(extra-y))
always-y	:= $(addprefix $(obj)/,$(always-y))
targets		:= $(addprefix $(obj)/,$(targets))
obj-m		:= $(addprefix $(obj)/,$(obj-m))
lib-y		:= $(addprefix $(obj)/,$(lib-y))
real-obj-y	:= $(addprefix $(obj)/,$(real-obj-y))
real-obj-m	:= $(addprefix $(obj)/,$(real-obj-m))
multi-used-m	:= $(addprefix $(obj)/,$(multi-used-m))
subdir-ym	:= $(addprefix $(obj)/,$(subdir-ym))

# Finds the multi-part object the current object will be linked into.
# If the object belongs to two or more multi-part objects, list them all.
modname-multi = $(sort $(foreach m,$(multi-used),\
		$(if $(filter $*.o, $($(m:.o=-objs)) $($(m:.o=-y)) $($(m:.o=-m))),$(m:.o=))))

__modname = $(if $(modname-multi),$(modname-multi),$(basetarget))

modname = $(subst $(space),:,$(__modname))
modfile = $(addprefix $(obj)/,$(__modname))

# target with $(obj)/ and its suffix stripped
target-stem = $(basename $(patsubst $(obj)/%,%,$@))

# These flags are needed for modversions and compiling, so we define them here
# $(modname_flags) defines KBUILD_MODNAME as the name of the module it will
# end up in (or would, if it gets compiled in)
name-fix = $(call stringify,$(subst $(comma),_,$(subst -,_,$1)))
basename_flags = -DKBUILD_BASENAME=$(call name-fix,$(basetarget))
modname_flags  = -DKBUILD_MODNAME=$(call name-fix,$(modname))
modfile_flags  = -DKBUILD_MODFILE=$(call stringify,$(modfile))

_c_flags       = $(filter-out $(CFLAGS_REMOVE_$(target-stem).o), \
                     $(filter-out $(ccflags-remove-y), \
                         $(KBUILD_CPPFLAGS) $(KBUILD_CFLAGS) $(ccflags-y)) \
                     $(CFLAGS_$(target-stem).o))
_a_flags       = $(filter-out $(AFLAGS_REMOVE_$(target-stem).o), \
                     $(filter-out $(asflags-remove-y), \
                         $(KBUILD_CPPFLAGS) $(KBUILD_AFLAGS) $(asflags-y)) \
                     $(AFLAGS_$(target-stem).o))
_cpp_flags     = $(KBUILD_CPPFLAGS) $(cppflags-y) $(CPPFLAGS_$(target-stem).lds)

#
# Enable gcov profiling flags for a file, directory or for all files depending
# on variables GCOV_PROFILE_obj.o, GCOV_PROFILE and CONFIG_GCOV_PROFILE_ALL
# (in this order)
#
ifeq ($(CONFIG_GCOV_KERNEL),y)
_c_flags += $(if $(patsubst n%,, \
		$(GCOV_PROFILE_$(basetarget).o)$(GCOV_PROFILE)$(CONFIG_GCOV_PROFILE_ALL)), \
		$(CFLAGS_GCOV))
endif

#
# Enable address sanitizer flags for kernel except some files or directories
# we don't want to check (depends on variables KASAN_SANITIZE_obj.o, KASAN_SANITIZE)
#
ifeq ($(CONFIG_KASAN),y)
ifneq ($(CONFIG_KASAN_HW_TAGS),y)
_c_flags += $(if $(patsubst n%,, \
		$(KASAN_SANITIZE_$(basetarget).o)$(KASAN_SANITIZE)y), \
		$(CFLAGS_KASAN), $(CFLAGS_KASAN_NOSANITIZE))
endif
endif

ifeq ($(CONFIG_UBSAN),y)
_c_flags += $(if $(patsubst n%,, \
		$(UBSAN_SANITIZE_$(basetarget).o)$(UBSAN_SANITIZE)$(CONFIG_UBSAN_SANITIZE_ALL)), \
		$(CFLAGS_UBSAN))
endif

ifeq ($(CONFIG_KCOV),y)
_c_flags += $(if $(patsubst n%,, \
	$(KCOV_INSTRUMENT_$(basetarget).o)$(KCOV_INSTRUMENT)$(CONFIG_KCOV_INSTRUMENT_ALL)), \
	$(CFLAGS_KCOV))
endif

#
# Enable KCSAN flags except some files or directories we don't want to check
# (depends on variables KCSAN_SANITIZE_obj.o, KCSAN_SANITIZE)
#
ifeq ($(CONFIG_KCSAN),y)
_c_flags += $(if $(patsubst n%,, \
	$(KCSAN_SANITIZE_$(basetarget).o)$(KCSAN_SANITIZE)y), \
	$(CFLAGS_KCSAN))
endif

# $(srctree)/$(src) for including checkin headers from generated source files
# $(objtree)/$(obj) for including generated headers from checkin source files
ifeq ($(KBUILD_EXTMOD),)
ifdef building_out_of_srctree
_c_flags   += -I $(srctree)/$(src) -I $(objtree)/$(obj)
_a_flags   += -I $(srctree)/$(src) -I $(objtree)/$(obj)
_cpp_flags += -I $(srctree)/$(src) -I $(objtree)/$(obj)
endif
endif

part-of-module = $(if $(filter $(basename $@).o, $(real-obj-m)),y)
quiet_modtag = $(if $(part-of-module),[M],   )

modkern_cflags =                                          \
	$(if $(part-of-module),                           \
		$(KBUILD_CFLAGS_MODULE) $(CFLAGS_MODULE), \
		$(KBUILD_CFLAGS_KERNEL) $(CFLAGS_KERNEL) $(modfile_flags))

modkern_aflags = $(if $(part-of-module),				\
			$(KBUILD_AFLAGS_MODULE) $(AFLAGS_MODULE),	\
			$(KBUILD_AFLAGS_KERNEL) $(AFLAGS_KERNEL))

c_flags        = -Wp,-MMD,$(depfile) $(NOSTDINC_FLAGS) $(LINUXINCLUDE)     \
		 -include $(srctree)/include/linux/compiler_types.h       \
		 $(_c_flags) $(modkern_cflags)                           \
		 $(basename_flags) $(modname_flags)

a_flags        = -Wp,-MMD,$(depfile) $(NOSTDINC_FLAGS) $(LINUXINCLUDE)     \
		 $(_a_flags) $(modkern_aflags)

cpp_flags      = -Wp,-MMD,$(depfile) $(NOSTDINC_FLAGS) $(LINUXINCLUDE)     \
		 $(_cpp_flags)

ld_flags       = $(KBUILD_LDFLAGS) $(ldflags-y) $(LDFLAGS_$(@F))

DTC_INCLUDE    := $(srctree)/scripts/dtc/include-prefixes

dtc_cpp_flags  = -Wp,-MMD,$(depfile).pre.tmp -nostdinc                    \
		 $(addprefix -I,$(DTC_INCLUDE))                          \
		 -undef -D__DTS__

# Useful for describing the dependency of composite objects
# Usage:
#   $(call multi_depend, multi_used_targets, suffix_to_remove, suffix_to_add)
define multi_depend
$(foreach m, $(notdir $1), \
	$(eval $(obj)/$m: \
	$(addprefix $(obj)/, $(foreach s, $3, $($(m:%$(strip $2)=%$(s)))))))
endef

quiet_cmd_copy = COPY    $@
      cmd_copy = cp $< $@

# Shipped files
# ===========================================================================

quiet_cmd_shipped = SHIPPED $@
cmd_shipped = cat $< > $@

$(obj)/%: $(src)/%_shipped
	$(call cmd,shipped)

# Commands useful for building a boot image
# ===========================================================================
#
#	Use as following:
#
#	target: source(s) FORCE
#		$(if_changed,ld/objcopy/gzip)
#
#	and add target to extra-y so that we know we have to
#	read in the saved command line

# Linking
# ---------------------------------------------------------------------------

quiet_cmd_ld = LD      $@
      cmd_ld = $(LD) $(ld_flags) $(real-prereqs) -o $@

# Archive
# ---------------------------------------------------------------------------

quiet_cmd_ar = AR      $@
      cmd_ar = rm -f $@; $(AR) cDPrsT $@ $(real-prereqs)

# Objcopy
# ---------------------------------------------------------------------------

quiet_cmd_objcopy = OBJCOPY $@
cmd_objcopy = $(OBJCOPY) $(OBJCOPYFLAGS) $(OBJCOPYFLAGS_$(@F)) $< $@

# Gzip
# ---------------------------------------------------------------------------

quiet_cmd_gzip = GZIP    $@
      cmd_gzip = cat $(real-prereqs) | $(KGZIP) -n -f -9 > $@

# DTC
# ---------------------------------------------------------------------------
DTC ?= $(objtree)/scripts/dtc/dtc
DTC_FLAGS += -Wno-interrupt_provider

# Disable noisy checks by default
ifeq ($(findstring 1,$(KBUILD_EXTRA_WARN)),)
DTC_FLAGS += -Wno-unit_address_vs_reg \
	-Wno-unit_address_format \
	-Wno-avoid_unnecessary_addr_size \
	-Wno-alias_paths \
	-Wno-graph_child_address \
	-Wno-simple_bus_reg \
	-Wno-unique_unit_address \
	-Wno-pci_device_reg
endif

ifneq ($(findstring 2,$(KBUILD_EXTRA_WARN)),)
DTC_FLAGS += -Wnode_name_chars_strict \
	-Wproperty_name_chars_strict \
	-Winterrupt_provider
endif

DTC_FLAGS += $(DTC_FLAGS_$(basetarget))

# Generate an assembly file to wrap the output of the device tree compiler
quiet_cmd_dt_S_dtb= DTB     $@
cmd_dt_S_dtb=						\
{							\
	echo '\#include <asm-generic/vmlinux.lds.h>'; 	\
	echo '.section .dtb.init.rodata,"a"';		\
	echo '.balign STRUCT_ALIGNMENT';		\
	echo '.global __dtb_$(subst -,_,$(*F))_begin';	\
	echo '__dtb_$(subst -,_,$(*F))_begin:';		\
	echo '.incbin "$<" ';				\
	echo '__dtb_$(subst -,_,$(*F))_end:';		\
	echo '.global __dtb_$(subst -,_,$(*F))_end';	\
	echo '.balign STRUCT_ALIGNMENT'; 		\
} > $@

$(obj)/%.dtb.S: $(obj)/%.dtb FORCE
	$(call if_changed,dt_S_dtb)

quiet_cmd_dtc = DTC     $@
cmd_dtc = $(HOSTCC) -E $(dtc_cpp_flags) -x assembler-with-cpp -o $(dtc-tmp) $< ; \
	$(DTC) -O $(patsubst .%,%,$(suffix $@)) -o $@ -b 0 \
		$(addprefix -i,$(dir $<) $(DTC_INCLUDE)) $(DTC_FLAGS) \
		-d $(depfile).dtc.tmp $(dtc-tmp) ; \
	cat $(depfile).pre.tmp $(depfile).dtc.tmp > $(depfile)

$(obj)/%.dtb: $(src)/%.dts $(DTC) FORCE
	$(call if_changed_dep,dtc)

DT_CHECKER ?= dt-validate
DT_BINDING_DIR := Documentation/devicetree/bindings
# DT_TMP_SCHEMA may be overridden from Documentation/devicetree/bindings/Makefile
DT_TMP_SCHEMA ?= $(objtree)/$(DT_BINDING_DIR)/processed-schema.json

quiet_cmd_dtb_check =	CHECK   $@
      cmd_dtb_check =	$(DT_CHECKER) -u $(srctree)/$(DT_BINDING_DIR) -p $(DT_TMP_SCHEMA) $@

define rule_dtc
	$(call cmd_and_fixdep,dtc)
	$(call cmd,dtb_check)
endef

$(obj)/%.dt.yaml: $(src)/%.dts $(DTC) $(DT_TMP_SCHEMA) FORCE
	$(call if_changed_rule,dtc,yaml)

dtc-tmp = $(subst $(comma),_,$(dot-target).dts.tmp)

# Bzip2
# ---------------------------------------------------------------------------

# Bzip2 and LZMA do not include size in file... so we have to fake that;
# append the size as a 32-bit littleendian number as gzip does.
size_append = printf $(shell						\
dec_size=0;								\
for F in $(real-prereqs); do					\
	fsize=$$($(CONFIG_SHELL) $(srctree)/scripts/file-size.sh $$F);	\
	dec_size=$$(expr $$dec_size + $$fsize);				\
done;									\
printf "%08x\n" $$dec_size |						\
	sed 's/\(..\)/\1 /g' | {					\
		read ch0 ch1 ch2 ch3;					\
		for ch in $$ch3 $$ch2 $$ch1 $$ch0; do			\
			printf '%s%03o' '\\' $$((0x$$ch)); 		\
		done;							\
	}								\
)

quiet_cmd_bzip2 = BZIP2   $@
      cmd_bzip2 = { cat $(real-prereqs) | $(KBZIP2) -9; $(size_append); } > $@

# Lzma
# ---------------------------------------------------------------------------

quiet_cmd_lzma = LZMA    $@
      cmd_lzma = { cat $(real-prereqs) | $(LZMA) -9; $(size_append); } > $@

quiet_cmd_lzo = LZO     $@
      cmd_lzo = { cat $(real-prereqs) | $(KLZOP) -9; $(size_append); } > $@

quiet_cmd_lz4 = LZ4     $@
      cmd_lz4 = { cat $(real-prereqs) | $(LZ4) -l -c1 stdin stdout; \
                  $(size_append); } > $@

# U-Boot mkimage
# ---------------------------------------------------------------------------

MKIMAGE := $(srctree)/scripts/mkuboot.sh

# SRCARCH just happens to match slightly more than ARCH (on sparc), so reduces
# the number of overrides in arch makefiles
UIMAGE_ARCH ?= $(SRCARCH)
UIMAGE_COMPRESSION ?= $(if $(2),$(2),none)
UIMAGE_OPTS-y ?=
UIMAGE_TYPE ?= kernel
UIMAGE_LOADADDR ?= arch_must_set_this
UIMAGE_ENTRYADDR ?= $(UIMAGE_LOADADDR)
UIMAGE_NAME ?= 'Linux-$(KERNELRELEASE)'

quiet_cmd_uimage = UIMAGE  $@
      cmd_uimage = $(BASH) $(MKIMAGE) -A $(UIMAGE_ARCH) -O linux \
			-C $(UIMAGE_COMPRESSION) $(UIMAGE_OPTS-y) \
			-T $(UIMAGE_TYPE) \
			-a $(UIMAGE_LOADADDR) -e $(UIMAGE_ENTRYADDR) \
			-n $(UIMAGE_NAME) -d $< $@

# XZ
# ---------------------------------------------------------------------------
# Use xzkern to compress the kernel image and xzmisc to compress other things.
#
# xzkern uses a big LZMA2 dictionary since it doesn't increase memory usage
# of the kernel decompressor. A BCJ filter is used if it is available for
# the target architecture. xzkern also appends uncompressed size of the data
# using size_append. The .xz format has the size information available at
# the end of the file too, but it's in more complex format and it's good to
# avoid changing the part of the boot code that reads the uncompressed size.
# Note that the bytes added by size_append will make the xz tool think that
# the file is corrupt. This is expected.
#
# xzmisc doesn't use size_append, so it can be used to create normal .xz
# files. xzmisc uses smaller LZMA2 dictionary than xzkern, because a very
# big dictionary would increase the memory usage too much in the multi-call
# decompression mode. A BCJ filter isn't used either.
quiet_cmd_xzkern = XZKERN  $@
      cmd_xzkern = { cat $(real-prereqs) | sh $(srctree)/scripts/xz_wrap.sh; \
                     $(size_append); } > $@

quiet_cmd_xzmisc = XZMISC  $@
      cmd_xzmisc = cat $(real-prereqs) | $(XZ) --check=crc32 --lzma2=dict=1MiB > $@

# ZSTD
# ---------------------------------------------------------------------------
# Appends the uncompressed size of the data using size_append. The .zst
# format has the size information available at the beginning of the file too,
# but it's in a more complex format and it's good to avoid changing the part
# of the boot code that reads the uncompressed size.
#
# Note that the bytes added by size_append will make the zstd tool think that
# the file is corrupt. This is expected.
#
# zstd uses a maximum window size of 8 MB. zstd22 uses a maximum window size of
# 128 MB. zstd22 is used for kernel compression because it is decompressed in a
# single pass, so zstd doesn't need to allocate a window buffer. When streaming
# decompression is used, like initramfs decompression, zstd22 should likely not
# be used because it would require zstd to allocate a 128 MB buffer.

quiet_cmd_zstd = ZSTD    $@
      cmd_zstd = { cat $(real-prereqs) | $(ZSTD) -19; $(size_append); } > $@

quiet_cmd_zstd22 = ZSTD22  $@
      cmd_zstd22 = { cat $(real-prereqs) | $(ZSTD) -22 --ultra; $(size_append); } > $@

# ASM offsets
# ---------------------------------------------------------------------------

# Default sed regexp - multiline due to syntax constraints
#
# Use [:space:] because LLVM's integrated assembler inserts <tab> around
# the .ascii directive whereas GCC keeps the <space> as-is.
define sed-offsets
	's:^[[:space:]]*\.ascii[[:space:]]*"\(.*\)".*:\1:; \
	/^->/{s:->#\(.*\):/* \1 */:; \
	s:^->\([^ ]*\) [\$$#]*\([^ ]*\) \(.*\):#define \1 \2 /* \3 */:; \
	s:->::; p;}'
endef

# Use filechk to avoid rebuilds when a header changes, but the resulting file
# does not
define filechk_offsets
	 echo "#ifndef $2"; \
	 echo "#define $2"; \
	 echo "/*"; \
	 echo " * DO NOT MODIFY."; \
	 echo " *"; \
	 echo " * This file was generated by Kbuild"; \
	 echo " */"; \
	 echo ""; \
	 sed -ne $(sed-offsets) < $<; \
	 echo ""; \
	 echo "#endif"
endef
