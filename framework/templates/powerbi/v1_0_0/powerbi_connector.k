"""
Power BI QuestDB Connector — Configuration and integration helper.

Power BI is a Microsoft tool that runs external to the cluster, but we can provide
a Kubernetes-native companion that exposes connection details, credentials, and
integration helpers for Power BI to connect to QuestDB and other data platforms.

This template creates ConfigMaps and Secrets that Power BI operators can use to
configure connections. It follows the same footprint-based sizing for documentation
and environment-specific connection strings.

Usage:
    import templates.powerbi.v1_0_0.powerbi_connector as pbi

    _spec = pbi.PowerBIConnectorSpec {
        name = "pbi-questdb-connector"
        namespace = "analytics"
        questdbHost = "questdb.infra.svc.cluster.local"
        questdbPort = 5432  # PostgreSQL wire protocol
    }
    _module = pbi.PowerBIConnectorModule {
        name = "pbi-questdb-connector"
        namespace = "analytics"
        questdbHost = "questdb.infra.svc.cluster.local"
        questdbPort = 5432
    }.instance
"""
import models.modules.component as component
import builders.configmap as cm
import builders.leader as leader

schema PowerBIConnectorSpec:
    """Specification for Power BI connector configuration."""
    name: str
    namespace: str

    # Primary data source: QuestDB
    questdbHost: str
    questdbPort: int = 5432
    questdbDatabase: str = "qdb"
    questdbUsername: str = "admin"
    # Password should be provided separately via Secret

    # Optional: Superset integration
    supersetHost?: str
    supersetPort?: int = 8088
    supersetUsername?: str

    # Optional: Direct PostgreSQL connection info (for other PG backends)
    postgresHost?: str
    postgresPort?: int = 5432
    postgresDatabase?: str
    postgresUsername?: str

    # Environment (for documentation strings and resource hints)
    footprint: str = "production"

    # Extra values
    extraData?: {str:str}

    check:
        len(name) > 0, "connector name must not be empty"
        len(namespace) > 0, "namespace must not be empty"
        len(questdbHost) > 0, "questdbHost must not be empty"
        questdbPort > 0 and questdbPort <= 65535, "questdbPort must be valid"

build_powerbi_connector_configmap = lambda spec: PowerBIConnectorSpec -> any {
    # Build connection strings and configuration data
    _questdb_conn_str = "Driver=PostgreSQL Unicode;Server=${spec.questdbHost};Port=${spec.questdbPort};Database=${spec.questdbDatabase};UID=${spec.questdbUsername}"

    # Create comprehensive documentation
    _connector_doc = "# Power BI QuestDB Connector Configuration\n\n## QuestDB Connection (PostgreSQL wire protocol)\n**Host:** ${spec.questdbHost}\n**Port:** ${spec.questdbPort}\n**Database:** ${spec.questdbDatabase}\n**Username:** ${spec.questdbUsername}\n\n**Connection String (ODBC):**\n${_questdb_conn_str}\n\n**Setup Instructions:**\n1. In Power BI Desktop: Get Data > Postgres\n2. Enter Server: ${spec.questdbHost}\n3. Enter Database: ${spec.questdbDatabase}\n4. Use DirectQuery for real-time analytics\n5. Enable Port ${spec.questdbPort} in firewall rules\n\n## Authentication\n- Username: ${spec.questdbUsername}\n- Password: (stored in Secret: ${spec.name}-credentials)\n"

    _config_data: {str:str} = {
        "connector-info.md" = _connector_doc
        "questdb-connection.txt" = _questdb_conn_str
    }

    _config_data = _config_data | (spec.extraData or {})

    cm.build_configmap(cm.ConfigMapSpec {
        name = spec.name
        namespace = spec.namespace
        data = _config_data
    })
}

schema PowerBIConnectorModule(component.Component):
    """High-level template for Power BI connector configuration."""
    kind = "APPLICATION"

    # Settings
    questdbHost: str
    questdbPort: int = 5432
    questdbDatabase: str = "qdb"
    questdbUsername: str = "admin"
    supersetHost?: str
    supersetPort?: int = 8088
    supersetUsername?: str
    postgresHost?: str
    postgresPort?: int = 5432
    postgresDatabase?: str
    postgresUsername?: str
    footprint: str = "production"
    extraData?: {str:str}

    # Auto-computed
    leaders = [leader.build_component_leader(name, namespace)]

    _spec = PowerBIConnectorSpec {
        name = name
        namespace = namespace
        questdbHost = questdbHost
        questdbPort = questdbPort
        questdbDatabase = questdbDatabase
        questdbUsername = questdbUsername
        if supersetHost:
            supersetHost = supersetHost
        if supersetPort:
            supersetPort = supersetPort
        if supersetUsername:
            supersetUsername = supersetUsername
        if postgresHost:
            postgresHost = postgresHost
        if postgresPort:
            postgresPort = postgresPort
        if postgresDatabase:
            postgresDatabase = postgresDatabase
        if postgresUsername:
            postgresUsername = postgresUsername
        footprint = footprint
        if extraData:
            extraData = extraData
    }

    manifests = [build_powerbi_connector_configmap(_spec)]



