#include <stddef.h>
#include <stdbool.h>
#include <string.h>

// Maximum number of services that can be managed
#define MAX_SERVICES 64

// Service states
typedef enum {
    SERVICE_STOPPED,
    SERVICE_STARTING,
    SERVICE_RUNNING,
    SERVICE_STOPPING,
    SERVICE_FAILED
} service_state_t;

// Service structure
typedef struct {
    char name[32];
    char exec_path[256];
    service_state_t state;
    int pid;
    bool autostart;
    int priority;
    char dependencies[8][32];  // Up to 8 dependencies
    int dep_count;
} service_t;

// Global service table
static service_t services[MAX_SERVICES];
static int service_count = 0;

// Initialize the init system
bool init_system_start(void) {
    // Clear service table
    memset(services, 0, sizeof(services));
    
    // Register essential system services
    register_service("syslog", "/sbin/syslogd", true, 1);
    register_service("devd", "/sbin/devd", true, 2);
    register_service("network", "/sbin/networkd", true, 3);
    register_service("storage", "/sbin/storaged", true, 3);
    
    // Start all autostart services
    return start_autostart_services();
}

// Register a new service
bool register_service(const char* name, const char* exec_path, bool autostart, int priority) {
    if (service_count >= MAX_SERVICES) {
        return false;
    }
    
    service_t* service = &services[service_count++];
    strncpy(service->name, name, sizeof(service->name) - 1);
    strncpy(service->exec_path, exec_path, sizeof(service->exec_path) - 1);
    service->autostart = autostart;
    service->priority = priority;
    service->state = SERVICE_STOPPED;
    service->pid = -1;
    service->dep_count = 0;
    
    return true;
}

// Start a service
bool start_service(const char* name) {
    service_t* service = find_service(name);
    if (!service || service->state != SERVICE_STOPPED) {
        return false;
    }
    
    // Check dependencies
    for (int i = 0; i < service->dep_count; i++) {
        service_t* dep = find_service(service->dependencies[i]);
        if (!dep || dep->state != SERVICE_RUNNING) {
            return false;
        }
    }
    
    // Start the service process
    service->state = SERVICE_STARTING;
    // TODO: Implement process creation and management
    service->state = SERVICE_RUNNING;
    
    return true;
}

// Stop a service
bool stop_service(const char* name) {
    service_t* service = find_service(name);
    if (!service || service->state != SERVICE_RUNNING) {
        return false;
    }
    
    service->state = SERVICE_STOPPING;
    // TODO: Implement process termination
    service->state = SERVICE_STOPPED;
    service->pid = -1;
    
    return true;
}

// Find a service by name
static service_t* find_service(const char* name) {
    for (int i = 0; i < service_count; i++) {
        if (strcmp(services[i].name, name) == 0) {
            return &services[i];
        }
    }
    return NULL;
}

// Start all autostart services
static bool start_autostart_services(void) {
    bool success = true;
    
    // Sort services by priority
    // Simple bubble sort
    for (int i = 0; i < service_count - 1; i++) {
        for (int j = 0; j < service_count - i - 1; j++) {
            if (services[j].priority > services[j + 1].priority) {
                service_t temp = services[j];
                services[j] = services[j + 1];
                services[j + 1] = temp;
            }
        }
    }
    
    // Start services in priority order
    for (int i = 0; i < service_count; i++) {
        if (services[i].autostart) {
            if (!start_service(services[i].name)) {
                success = false;
            }
        }
    }
    
    return success;
}
