# Setup the default target.
include forge/setup_default_target.mk

# Perform recursive build if it's necessary.
include forge/setup_recursive_build.mk

# From this point we're in the main build process.
# Setup the build.
include forge/setup_build.mk
