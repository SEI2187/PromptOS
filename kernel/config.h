#ifndef PROMPTOS_KERNEL_CONFIG_H
#define PROMPTOS_KERNEL_CONFIG_H

// Kernel version information
#define KERNEL_VERSION_MAJOR    0
#define KERNEL_VERSION_MINOR    1
#define KERNEL_VERSION_PATCH    0

// System configuration
#define MAX_PROCESSES          1024
#define MAX_THREADS_PER_PROC   128
#define KERNEL_STACK_SIZE      8192
#define USER_STACK_SIZE        4096
#define PAGE_SIZE              4096
#define KERNEL_HEAP_SIZE       (256 * 1024 * 1024)  // 256MB

// Memory management
#define VIRTUAL_MEMORY_ENABLED 1
#define PAGING_ENABLED         1
#define MAX_PHYSICAL_MEMORY    (4ULL * 1024 * 1024 * 1024)  // 4GB

// Scheduling configuration
#define SCHEDULER_TIMESLICE_MS 10
#define PRIORITY_LEVELS        32

// File system
#define MAX_OPEN_FILES         256
#define MAX_FILE_SIZE          (1ULL * 1024 * 1024 * 1024)  // 1GB
#define MAX_PATH_LENGTH        256

// Device management
#define MAX_DEVICES            32
#define DEVICE_NAME_LENGTH     32

// System calls
#define MAX_SYSCALLS          256

// Security
#define SECURITY_LEVELS        4
#define MAX_USER_GROUPS        32

// Debugging
#define DEBUG_LEVEL           3  // 0=off, 1=error, 2=warn, 3=info, 4=debug
#define KERNEL_LOG_BUFFER_SIZE (64 * 1024)

#endif // PROMPTOS_KERNEL_CONFIG_H