# Compiler and linker.
CC := clang

# Target.
TARGET := main

# Directories.
SRC_DIR := src
INC_DIRS := inc

BUILD_DIR := build

EXT_INC_DIRS :=

# Flags.
FLAGS :=
FLAGS_DEBUG := -g -DDEBUG
FLAGS_RELEASE := -O3 -DRELEASE

CFLAGS := -std=c17
CFLAGS_DEBUG :=
CFLAGS_RELEASE :=

LDFLAGS :=

#######################################################################

BUILD_MODE_DEBUG := debug
BUILD_MODE_RELEASE := release

ifndef BUILD_MDOE
	BUILD_MODE := $(BUILD_MODE_DEBUG)
endif

ifeq ($(BUILD_MODE), $(BUILD_MODE_DEBUG))
	FLAGS := $(FLAGS) $(FLAGS_DEBUG)
	CFLAGS := $(CFLAGS) $(CFLAGS_DEBUG)
else ifeq ($(BUILD_MODE), $(BUILD_MODE_RELEASE))
	FLAGS := $(FLAGS) $(FLAGS_RELEASE)
	CFLAGS := $(CFLAGS) $(CFLAGS_RELEASE)
else
$(error Unsupported build mode: [$(BUILD_MODE)])
endif

#######################################################################

BIN_DIR := $(BUILD_DIR)/$(BUILD_MODE)/bin
OBJ_DIR := $(BUILD_DIR)/obj/$(BUILD_MODE)

TARGET_PATH := $(BIN_DIR)/$(TARGET)

C_SRCS := $(shell find $(SRC_DIR) -type f -name *.c)

INCS := $(patsubst %, -I%, $(INC_DIRS))
EXT_INCS := $(patsubst %, -isystem %, $(EXT_INC_DIRS))

C_OBJS := $(patsubst $(SRC_DIR)/%, $(OBJ_DIR)/%, $(C_SRCS:.c=.o))

#######################################################################

all: $(BIN_DIR)/kernel.elf
	$(MAKE) -C kernel

remake: clean all

clean:
	@$(RM) -rf $(BUILD_DIR)

$(TARGET_PATH): $(C_OBJS) | $(BIN_DIR)
	@$(CC) $(FLAGS) $(LDFLAGS) $^ -o $@
	@echo "LD $@"

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(OBJ_DIR)
	@$(CC) $(FLAGS) $(CFLAGS) $(INCS) -c $< -o $@
	@echo "CC $<"

$(BIN_DIR):
	@mkdir -p $@

.PHONY: all remake clean
