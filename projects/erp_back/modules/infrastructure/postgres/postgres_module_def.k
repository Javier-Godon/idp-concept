"""
PostgreSQL Module — single-instance PostgreSQL database.
Uses the SingleDatabaseModule template from framework, reducing ~120 lines to ~20.
"""
import framework.templates.database as database
import framework.builders.deployment as deploy

schema PostgresModule(database.SingleDatabaseModule):
    port = 5432
    portName = "postgresql"
    dataPath = "/var/lib/postgresql/data"
    storageSize = "20Gi"
    storageHostPath = "/mnt/data"
    serviceType = "ClusterIP"

    resources = deploy.ResourceSpec {
        cpuRequest = "250m"
        cpuLimit = "1"
        memoryRequest = "512Mi"
        memoryLimit = "2Gi"
    }

    env = [
        {
            name = "POSTGRES_DB"
            value = "erp_db"
        }
        {
            name = "POSTGRES_USER"
            valueFrom = {
                secretKeyRef = {
                    name = "erp-db-credentials"
                    key = "username"
                }
            }
        }
        {
            name = "POSTGRES_PASSWORD"
            valueFrom = {
                secretKeyRef = {
                    name = "erp-db-credentials"
                    key = "password"
                }
            }
        }
    ]
