# Version info.
NAME := alloy
MAJOR := 0
MINOR := 1
PATCH := 0

# To see a list of typical targets execute "make help"
# More info can be located in ./README
# Comments in this file are targeted only to the developer, do not
# expect to learn how to build the kernel reading this file.

$(if $(filter __%, $(MAKECMDGOALS)), \
	$(error targets prefixed with '__' are only for internal use))

# That's our default target when none is given on the command line
PHONY := __all
__all:

# ===========================================================================
# We are using a recursive build, so we need to do a little thinking
# to get the ordering right.
#
# Most importantly: sub-Makefiles should only ever modify files in
# their own directory. If in some directory we have a dependency on
# a file in another dir (which doesn't happen often, but it's often
# unavoidable when linking the built-in.a targets which finally
# turn into vmlinux), we will call a sub make in that other dir, and
# after that we are sure that everything which is in that other dir
# is now up to date.
#
# The only cases where we need to modify files which have global
# effects are thus separated out and done before the recursive
# descending is started. They are now explicitly listed as the
# prepare rule.

ifneq ($(sub_make_done),1)

# Do not use make's built-in rules and variables
# (this increases performance and avoids hard-to-debug behaviour)
MAKEFLAGS += -rR

# Avoid funny character set dependencies
unexport LC_ALL
LC_COLLATE=C
LC_NUMERIC=C
export LC_COLLATE LC_NUMERIC

# Avoid interference with shell env settings
unexport GREP_OPTIONS

# Beautify output
# ---------------------------------------------------------------------------
#
# Normally, we echo the whole command before executing it. By making
# that echo $($(quiet)$(cmd)), we now have the possibility to set
# $(quiet) to choose other forms of output instead, e.g.
#
#         quiet_cmd_cc_o_c = Compiling $(RELDIR)/$@
#         cmd_cc_o_c       = $(CC) $(c_flags) -c -o $@ $<
#
# If $(quiet) is empty, the whole command will be printed.
# If it is set to "quiet_", only the short version will be printed.
# If it is set to "silent_", nothing will be printed at all, since
# the variable $(silent_cmd_cc_o_c) doesn't exist.
#
# A simple variant is to prefix commands with $(Q) - that's useful
# for commands that shall be hidden in non-verbose mode.
#
#	$(Q)ln $@ :<
#
# If KBUILD_VERBOSE equals 0 then the above command will be hidden.
# If KBUILD_VERBOSE equals 1 then the above command is displayed.
# If KBUILD_VERBOSE equals 2 then give the reason why each target is rebuilt.
#
# To put more focus on warnings, be less verbose as default
# Use 'make V=1' to see the full commands

ifeq ("$(origin V)", "command line")
  KBUILD_VERBOSE = $(V)
endif
ifndef KBUILD_VERBOSE
  KBUILD_VERBOSE = 0
endif

ifeq ($(KBUILD_VERBOSE),1)
  quiet =
  Q =
else
  quiet=quiet_
  Q = @
endif

# If the user is running make -s (silent mode), suppress echoing of
# commands

ifneq ($(findstring s,$(filter-out --%,$(MAKEFLAGS))),)
  quiet=silent_
endif

export quiet Q KBUILD_VERBOSE

# Kbuild will save output files in the current working directory.
# This does not need to match to the root of the kernel source tree.
#
# For example, you can do this:
#
#  cd /dir/to/store/output/files; make -f /dir/to/kernel/source/Makefile
#
# If you want to save output files in a different location, there are
# two syntaxes to specify it.
#
# 1) O=
# Use "make O=dir/to/store/output/files/"
#
# 2) Set KBUILD_OUTPUT
# Set the environment variable KBUILD_OUTPUT to point to the output directory.
# export KBUILD_OUTPUT=dir/to/store/output/files/; make
#
# The O= assignment takes precedence over the KBUILD_OUTPUT environment
# variable.

# Do we want to change the working directory?
ifeq ("$(origin O)", "command line")
  KBUILD_OUTPUT := $(O)
endif

ifneq ($(KBUILD_OUTPUT),)
  # Make's built-in functions such as $(abspath ...), $(realpath ...) cannot
  # expand a shell special character '~'. We use a somewhat tedious way here.
  abs_objtree := $(shell mkdir -p $(KBUILD_OUTPUT) && cd $(KBUILD_OUTPUT) && pwd)
  $(if $(abs_objtree),, \
       $(error failed to create output directory "$(KBUILD_OUTPUT)"))

  # $(realpath ...) resolves symlinks
  abs_objtree := $(realpath $(abs_objtree))
else
  abs_objtree := $(CURDIR)
endif

ifeq ($(abs_objtree),$(CURDIR))
  # Suppress "Entering directory ..." unless we are changing the work directory.
  MAKEFLAGS += --no-print-directory
else
  need-sub-make := 1
endif

abs_srctree := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

ifneq ($(words $(subst :, ,$(abs_srctree))), 1)
  $(error source directory cannot contain spaces or colons)
endif

ifneq ($(abs_srctree),$(abs_objtree))
  # Look for make include files relative to root of kernel src
  #
  # This does not become effective immediately because MAKEFLAGS is re-parsed
  # once after the Makefile is read. We need to invoke sub-make.
  MAKEFLAGS += --include-dir=$(abs_srctree)
  need-sub-make := 1
endif

this-makefile := $(lastword $(MAKEFILE_LIST))

ifneq ($(filter 3.%,$(MAKE_VERSION)),)
  # 'MAKEFLAGS += -rR' does not immediately become effective for GNU Make 3.x
  # We need to invoke sub-make to avoid implicit rules in the top Makefile.
  need-sub-make := 1

  # Cancel implicit rules for this Makefile.
$(this-makefile): ;
endif

export abs_srctree abs_objtree
export sub_make_done := 1

ifeq ($(need-sub-make),1)

  PHONY += $(MAKECMDGOALS) __sub-make

$(filter-out $(this-makefile), $(MAKECMDGOALS)) __all: __sub-make
	@:

  # Invoke a second make in the output directory, passing relevant variables
__sub-make:
	$(Q)$(MAKE) -C $(abs_objtree) -f $(abs_srctree)/Makefile $(MAKECMDGOALS)

endif # ifeq ($(need-sub-make),1)
endif # ifneq ($(sub_make_done),1)

# ===========================================================================
# We process the rest of the Makefile if this is the final invocation of make
ifeq ($(need-sub-make),)

# Do not print "Entering directory ...",
# but we want to display it when entering to the output directory
# so that IDEs/editors are able to understand relative filenames.
MAKEFLAGS += --no-print-directory

# Call a source code checker (by default, "sparse") as part of the
# C compilation.
#
# Use 'make C=1' to enable checking of only re-compiled files.
# Use 'make C=2' to enable checking of *all* source files, regardless
# of whether they are re-compiled or not.
#
# See the file "Documentation/dev-tools/sparse.rst" for more details,
# including where to get the "sparse" utility.

ifeq ("$(origin C)", "command line")
  KBUILD_CHECKSRC = $(C)
endif
ifndef KBUILD_CHECKSRC
  KBUILD_CHECKSRC = 0
endif
