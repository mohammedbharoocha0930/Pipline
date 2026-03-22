# ============================================================================
# Compiler settings
CC = gcc
CFLAGS = -std=c17 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror -Wno-deprecated-declarations -g -O0 -pthread
LDFLAGS =

# ============================================================================
# Project settings
TARGET = pipeline
SOURCES = pipeline_driver.c pipeline.c 
HEADERS = pipeline.h

# ============================================================================
# Build Rules
# ============================================================================

# Default target
all: $(TARGET)

# Main build rule - creates the executable
$(TARGET): $(SOURCES) $(HEADERS)
	@echo "Building $(TARGET)..."
	$(CC) $(CFLAGS) $(SOURCES) -o $(TARGET) $(LDFLAGS)
	@echo " "
	@echo "Build successful! "
	@echo "Run with: ./$(TARGET) <testcase>"
	@echo "Example: ./$(TARGET) Testing/Testcases/input1.txt"

# Clean up generated files
clean:
	@echo "Cleaning up..."
	rm -f $(TARGET) *.o STUDENT_OUTPUT.txt
	@echo "Cleanup complete."

# Rebuild everything from scratch
rebuild: clean all

# Show available commands
help:
	@echo "Available commands:"
	@echo "  make       - Build the program"
	@echo "  make run   - Build and run with TESTCASES.txt"
	@echo "  make clean - Remove generated files"
	@echo "  make rebuild - Clean and build from scratch"

# Declare phony targets
.PHONY: all run clean rebuild help