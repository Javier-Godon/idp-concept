import framework.models.project
import erp_back.kernel.configurations

erp_back_project = project.Project {
    name = "ERP Back"
    description = "Enterprise Resource Planning backend — Spring Boot API with PostgreSQL"
    configurations = configurations._erp_back_kernel_configurations
}
