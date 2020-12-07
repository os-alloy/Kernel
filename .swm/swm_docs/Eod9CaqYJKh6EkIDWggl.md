# Overview
The Alloy kernel is built using the Forge build system which is a wrapper for the Make build system
specialized for the Alloy operating system.
To learn about the Forge build system, see the Forge repo documentation.

# Forging the Alloy Kernel
The Alloy kernel can be built by executing the `make` command.

To see all available build targets, use:
```make help```

To configure the Kernel, use:
```make menuconfig```

Then, to build the Kernel, use:
```make```