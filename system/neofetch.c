#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/utsname.h>
#include <sys/sysinfo.h>

#define BUFFER_SIZE 1024
#define COLOR_RESET "\033[0m"
#define COLOR_BOLD "\033[1m"
#define COLOR_BLUE "\033[34m"

// ASCII art logo for PromptOS
static const char* LOGO[] = {
    "blahaj hehehehe",

    NULL
};

// Get system information
static void get_system_info(char* buffer, size_t size) {
    struct utsname sys_info;
    struct sysinfo si;
    
    if (uname(&sys_info) < 0) {
        snprintf(buffer, size, "Error getting system information\n");
        return;
    }
    
    if (sysinfo(&si) < 0) {
        snprintf(buffer, size, "Error getting system information\n");
        return;
    }
    
    // Format memory sizes
    unsigned long total_ram = si.totalram * si.mem_unit / (1024 * 1024);
    unsigned long free_ram = si.freeram * si.mem_unit / (1024 * 1024);
    unsigned long used_ram = total_ram - free_ram;
    
    // Get current user
    char* username = getenv("USER");
    if (!username) username = "root";
    
    // Get hostname
    char hostname[256] = {0};
    gethostname(hostname, sizeof(hostname));
    
    // Format system information
    snprintf(buffer, size,
        "\n%s@%s\n"
        "---------------\n"
        "OS: PromptOS %s\n"
        "Kernel: %s %s\n"
        "Uptime: %ld days, %ld hours, %ld mins\n"
        "Memory: %luMB / %luMB (Used/Total)\n"
        "Architecture: %s\n"
        "Shell: %s\n",
        username, hostname,
        "1.0.0",  // OS version
        sys_info.sysname, sys_info.release,
        si.uptime / 86400, (si.uptime % 86400) / 3600, (si.uptime % 3600) / 60,
        used_ram, total_ram,
        sys_info.machine,
        getenv("SHELL") ? getenv("SHELL") : "bash"
    );
}

// Display the logo and system information
static void display_info(void) {
    char info_buffer[BUFFER_SIZE];
    get_system_info(info_buffer, sizeof(info_buffer));
    
    // Print logo and information side by side
    const char** logo_line = LOGO;
    char* info_line = info_buffer;
    char* next_line;
    
    printf("\n%s", COLOR_BLUE);  // Set blue color for logo
    
    while (*logo_line) {
        next_line = strchr(info_line, '\n');
        if (next_line) {
            *next_line = '\0';
        }
        
        printf("%-60s", *logo_line);  // Print logo line
        if (*info_line) {
            printf("%s%s", COLOR_BOLD, info_line);  // Print info line
        }
        printf("\n");
        
        logo_line++;
        if (next_line) {
            info_line = next_line + 1;
        } else {
            info_line = "";
        }
    }
    
    // Print remaining info lines if any
    while (*info_line) {
        next_line = strchr(info_line, '\n');
        if (next_line) {
            *next_line = '\0';
            printf("%-60s%s%s\n", "", COLOR_BOLD, info_line);
            info_line = next_line + 1;
        } else {
            if (*info_line) {
                printf("%-60s%s%s\n", "", COLOR_BOLD, info_line);
            }
            break;
        }
    }
    
    printf(COLOR_RESET "\n");  // Reset colors
}

// Service lifecycle functions
static bool neofetch_start(void) {
    display_info();
    return true;
}

static bool neofetch_stop(void) {
    return true;
}

static void neofetch_status(char* buffer, size_t size) {
    snprintf(buffer, size, "Neofetch service is ready");
}

// Initialize neofetch service
bool init_neofetch_service(void) {
    Service neofetch = {
        .name = "neofetch",
        .description = "System information display utility",
        .type = SERVICE_TYPE_USER,
        .state = SERVICE_STATE_INACTIVE,
        .priority = 10,
        .enabled = true,
        .start = neofetch_start,
        .stop = neofetch_stop,
        .reload = NULL,
        .status = neofetch_status
    };
    
    return service_register(&neofetch);
}