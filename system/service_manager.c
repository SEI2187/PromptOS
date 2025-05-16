#include <stddef.h>
#include <stdbool.h>
#include <string.h>

// Service manager configuration
#define MAX_SERVICE_NAME_LEN 64
#define MAX_SERVICE_DESC_LEN 256
#define MAX_SERVICES 128
#define MAX_DEPENDENCIES 16

// Service states
typedef enum {
    SERVICE_STATE_INACTIVE,
    SERVICE_STATE_STARTING,
    SERVICE_STATE_ACTIVE,
    SERVICE_STATE_STOPPING,
    SERVICE_STATE_FAILED
} ServiceState;

// Service type
typedef enum {
    SERVICE_TYPE_SYSTEM,    // Core system service
    SERVICE_TYPE_NETWORK,   // Network-related service
    SERVICE_TYPE_USER       // User-space service
} ServiceType;

// Service dependency
typedef struct {
    char name[MAX_SERVICE_NAME_LEN];
    bool required;  // If true, service won't start without this dependency
} ServiceDependency;

// Service definition
typedef struct {
    char name[MAX_SERVICE_NAME_LEN];
    char description[MAX_SERVICE_DESC_LEN];
    ServiceType type;
    ServiceState state;
    int priority;  // Lower number = higher priority
    bool enabled;  // If service should start automatically
    
    // Dependencies
    ServiceDependency dependencies[MAX_DEPENDENCIES];
    int dependency_count;
    
    // Process information
    int pid;
    int exit_code;
    
    // Service lifecycle handlers
    bool (*start)(void);
    bool (*stop)(void);
    bool (*reload)(void);
    void (*status)(char* buffer, size_t size);
} Service;

// Global service registry
static Service services[MAX_SERVICES];
static int service_count = 0;

// Initialize the service manager
bool service_manager_init(void) {
    memset(services, 0, sizeof(services));
    return true;
}

// Register a new service
bool service_register(Service* service) {
    if (service_count >= MAX_SERVICES) {
        return false;
    }
    
    // Check for duplicate service
    for (int i = 0; i < service_count; i++) {
        if (strcmp(services[i].name, service->name) == 0) {
            return false;
        }
    }
    
    // Add service to registry
    memcpy(&services[service_count], service, sizeof(Service));
    service_count++;
    return true;
}

// Start a service and its dependencies
bool service_start(const char* name) {
    Service* service = service_find(name);
    if (!service) {
        return false;
    }
    
    // Check if service is already active
    if (service->state == SERVICE_STATE_ACTIVE) {
        return true;
    }
    
    // Start dependencies first
    for (int i = 0; i < service->dependency_count; i++) {
        Service* dep = service_find(service->dependencies[i].name);
        if (!dep) {
            if (service->dependencies[i].required) {
                return false;
            }
            continue;
        }
        
        if (!service_start(dep->name)) {
            if (service->dependencies[i].required) {
                return false;
            }
        }
    }
    
    // Start the service
    service->state = SERVICE_STATE_STARTING;
    if (service->start && service->start()) {
        service->state = SERVICE_STATE_ACTIVE;
        return true;
    }
    
    service->state = SERVICE_STATE_FAILED;
    return false;
}

// Stop a service
bool service_stop(const char* name) {
    Service* service = service_find(name);
    if (!service || service->state != SERVICE_STATE_ACTIVE) {
        return false;
    }
    
    service->state = SERVICE_STATE_STOPPING;
    if (service->stop && service->stop()) {
        service->state = SERVICE_STATE_INACTIVE;
        return true;
    }
    
    service->state = SERVICE_STATE_FAILED;
    return false;
}

// Find a service by name
static Service* service_find(const char* name) {
    for (int i = 0; i < service_count; i++) {
        if (strcmp(services[i].name, name) == 0) {
            return &services[i];
        }
    }
    return NULL;
}

// Start all enabled services in priority order
bool service_start_enabled(void) {
    bool success = true;
    
    // Sort services by priority
    for (int i = 0; i < service_count - 1; i++) {
        for (int j = 0; j < service_count - i - 1; j++) {
            if (services[j].priority > services[j + 1].priority) {
                Service temp = services[j];
                services[j] = services[j + 1];
                services[j + 1] = temp;
            }
        }
    }
    
    // Start enabled services
    for (int i = 0; i < service_count; i++) {
        if (services[i].enabled) {
            if (!service_start(services[i].name)) {
                success = false;
            }
        }
    }
    
    return success;
}