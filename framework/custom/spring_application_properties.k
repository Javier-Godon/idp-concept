"""
Spring Boot application.properties helper.

This file intentionally separates two concerns:
- Standard Spring Boot sections that are useful for a general-purpose IDP.
- Free-form maps for project/team-specific or newly introduced Spring properties.

Use `build_properties()` to get a `{str:str}` map suitable for ConfigMap data.
The `extraProperties` map is applied last and can override any generated value.
"""

_bool = lambda value: bool -> str {
    "true" if value else "false"
}

_csv = lambda values: [str] -> str {
    ",".join(values)
}

schema ApplicationProperties:
    """General-purpose Spring Boot properties specification.

    The fields below cover common Spring Boot defaults without forcing any team-specific
    convention. Add anything missing with `properties` or `extraProperties`.
    """
    applicationName?: str
    serverPort?: int
    contextPath?: str

    server?: ServerProperties
    spring?: SpringProperties
    # Accepts ManagementProperties for new code and ModuleManagement for legacy code.
    management?: any
    logging?: LoggingProperties
    springdoc?: SpringDocProperties
    security?: SecurityProperties

    # Free-form property maps. `extraProperties` wins over generated values.
    properties?: {str:str}
    extraProperties?: {str:str}

    # Backward-compatible, team-specific fields. Prefer the standard sections above
    # for new modules and keep these only for existing project definitions.
    moduleSpring?: ModuleSpring
    jwtAuthKcClientId?: str
    flyway?: SubModuleFlyway
    keycloak?: ModuleKeycloak
    managementLegacy?: ModuleManagement
    springDoc?: ModuleSpringDoc
    opensearchClient?: ModuleOpensearchClient
    questdbClient?: ModuleQuestDBClient
    scheduler?: scheduler

schema ServerProperties:
    port?: int
    servletContextPath?: str
    shutdown?: str
    compressionEnabled?: bool
    forwardHeadersStrategy?: str
    errorIncludeMessage?: str

schema SpringProperties:
    applicationName?: str
    profilesActive?: [str]
    configImport?: str
    mainBannerMode?: str
    datasource?: DatasourceProperties
    jpa?: JpaProperties
    flyway?: FlywayProperties
    jackson?: JacksonProperties
    cache?: CacheProperties
    kafka?: KafkaProperties
    rabbitmq?: RabbitMQProperties

schema DatasourceProperties:
    url?: str
    username?: str
    password?: str
    driverClassName?: str
    hikariMaximumPoolSize?: int
    hikariMinimumIdle?: int
    hikariConnectionTimeout?: int

schema JpaProperties:
    databasePlatform?: str
    hibernateDdlAuto?: str
    showSql?: bool
    openInView?: bool
    properties?: {str:str}

schema FlywayProperties:
    enabled?: bool
    locations?: [str]
    schemas?: [str]
    table?: str
    baselineOnMigrate?: bool
    createSchemas?: bool

schema JacksonProperties:
    timeZone?: str
    dateFormat?: str
    defaultPropertyInclusion?: str

schema CacheProperties:
    $type?: str
    cacheNames?: [str]

schema KafkaProperties:
    bootstrapServers?: [str]
    clientId?: str
    consumerGroupId?: str
    properties?: {str:str}

schema RabbitMQProperties:
    host?: str
    port?: int
    username?: str
    password?: str
    virtualHost?: str

schema ManagementProperties:
    securityEnabled?: bool
    serverPort?: int
    endpointsWebExposureInclude?: [str]
    endpointHealthShowDetails?: str
    endpointHealthProbesEnabled?: bool
    metricsTagsApplication?: str

schema LoggingProperties:
    level?: {str:str}
    patternConsole?: str
    fileName?: str

schema SpringDocProperties:
    apiDocsEnabled?: bool
    apiDocsPath?: str
    swaggerUiEnabled?: bool
    swaggerUiPath?: str
    swaggerUiDisableSwaggerDefaultUrl?: bool
    packagesToScan?: [str]

schema SecurityProperties:
    oauth2ResourceServerJwtIssuerUri?: str
    oauth2ResourceServerJwtJwkSetUri?: str

schema ModuleSpring:
    postgres?: SubModulePostgres
    questdb?: SubModuleQuestDB
    flyway?: SubModuleFlyway
    oauth2Security?: SubModuleOauth2Security

schema SubModulePostgres:
    driverClassName: str = "org.postgresql.Driver"
    namespace: str
    username: str
    password: str
    database?: str
    port?: int = 5432
    testOnBorrow?: bool
    validationQuery?: str

schema SubModuleQuestDB:
    driverClassName: str = "org.postgresql.Driver"
    namespace: str
    username: str
    password: str
    database?: str
    port?: int = 8812

schema SubModuleFlyway:
    flywayBoundedContext: [FlywayBoundedContext]

schema FlywayBoundedContext:
    schemas: str | [str]
    locations: [str]
    table?: str = "flyway_schema_history"
    baselineOnMigrate?: bool
    createSchemas?: bool = True

schema SubModuleOauth2Security:
    providerUrl: str
    realm: str

schema ModuleKeycloak:
    enabled: bool = True
    authServerUrl?: str
    realm: str
    bearerOnly: bool = True
    resource: str = "frontend"
    useResourceRoleMappings: bool = True
    principalAttribute: str = "preferred_username"
    cors: bool = False
    sslRequired: str = "none"
    publicClient: bool = True

schema ModuleSpringDoc:
    apiDocs: ApiDocs
    apiDocConfigGroup?: [ApiDocConfigGroup]
    swaggerUi: SwaggerUi

schema SwaggerUi:
    disableSwaggerDefaultUrl: bool = True
    url: str
    configUrl: str = url + "/swagger-config"
    groupUrls?: [GroupUrl]

schema GroupUrl:
    name: str
    url: str

schema ApiDocs:
    rootPath: str
    enableGroups: bool = True

schema ApiDocConfigGroup:
    group: str
    packagesToScan: str

schema ModuleOpensearchClient:
    httpsEnabled: bool = True
    hostname: str = "opensearch.opensearch"
    pathPrefix: str = "/"
    port: int = 9200
    user?: str
    password?: str
    enableSendData: bool = True

schema ModuleQuestDBClient:
    address: str
    localZone: str = "Europe/Madrid"
    questDBTables: {str:str}

schema ModuleManagement:
    securityEnabled: bool = False
    serverPort: int
    endpointsWebExposureInclude?: [str]
    endpointHealthShowDetails: str = "always"
    endpointHealthProbesEnabled?: bool
    metricsTagsApplication?: str

schema scheduler:
    timeExpression: str
    activations: {str:str}

build_properties = lambda spec: ApplicationProperties -> {str:str} {
    _base: {str:str} = {
        if spec.applicationName:
            "spring.application.name" = spec.applicationName
        if spec.serverPort != Undefined:
            "server.port" = str(spec.serverPort)
        if spec.contextPath:
            "server.servlet.context-path" = spec.contextPath
        if spec.jwtAuthKcClientId:
            "jwt.auth.kc-client-id" = spec.jwtAuthKcClientId
    }

    _server: {str:str} = {
        if spec.server != Undefined and spec.server.port != Undefined:
            "server.port" = str(spec.server.port)
        if spec.server != Undefined and spec.server.servletContextPath:
            "server.servlet.context-path" = spec.server.servletContextPath
        if spec.server != Undefined and spec.server.shutdown:
            "server.shutdown" = spec.server.shutdown
        if spec.server != Undefined and spec.server.compressionEnabled != Undefined:
            "server.compression.enabled" = _bool(spec.server.compressionEnabled)
        if spec.server != Undefined and spec.server.forwardHeadersStrategy:
            "server.forward-headers-strategy" = spec.server.forwardHeadersStrategy
        if spec.server != Undefined and spec.server.errorIncludeMessage:
            "server.error.include-message" = spec.server.errorIncludeMessage
    }

    _spring: {str:str} = {
        if spec.spring != Undefined and spec.spring.applicationName:
            "spring.application.name" = spec.spring.applicationName
        if spec.spring != Undefined and spec.spring.profilesActive:
            "spring.profiles.active" = _csv(spec.spring.profilesActive)
        if spec.spring != Undefined and spec.spring.configImport:
            "spring.config.import" = spec.spring.configImport
        if spec.spring != Undefined and spec.spring.mainBannerMode:
            "spring.main.banner-mode" = spec.spring.mainBannerMode
    }

    _datasource: {str:str} = {
        if spec.spring != Undefined and spec.spring.datasource != Undefined and spec.spring.datasource.url:
            "spring.datasource.url" = spec.spring.datasource.url
        if spec.spring != Undefined and spec.spring.datasource != Undefined and spec.spring.datasource.username:
            "spring.datasource.username" = spec.spring.datasource.username
        if spec.spring != Undefined and spec.spring.datasource != Undefined and spec.spring.datasource.password:
            "spring.datasource.password" = spec.spring.datasource.password
        if spec.spring != Undefined and spec.spring.datasource != Undefined and spec.spring.datasource.driverClassName:
            "spring.datasource.driver-class-name" = spec.spring.datasource.driverClassName
        if spec.spring != Undefined and spec.spring.datasource != Undefined and spec.spring.datasource.hikariMaximumPoolSize != Undefined:
            "spring.datasource.hikari.maximum-pool-size" = str(spec.spring.datasource.hikariMaximumPoolSize)
        if spec.spring != Undefined and spec.spring.datasource != Undefined and spec.spring.datasource.hikariMinimumIdle != Undefined:
            "spring.datasource.hikari.minimum-idle" = str(spec.spring.datasource.hikariMinimumIdle)
        if spec.spring != Undefined and spec.spring.datasource != Undefined and spec.spring.datasource.hikariConnectionTimeout != Undefined:
            "spring.datasource.hikari.connection-timeout" = str(spec.spring.datasource.hikariConnectionTimeout)
    }

    _jpa: {str:str} = {
        if spec.spring != Undefined and spec.spring.jpa != Undefined and spec.spring.jpa.databasePlatform:
            "spring.jpa.database-platform" = spec.spring.jpa.databasePlatform
        if spec.spring != Undefined and spec.spring.jpa != Undefined and spec.spring.jpa.hibernateDdlAuto:
            "spring.jpa.hibernate.ddl-auto" = spec.spring.jpa.hibernateDdlAuto
        if spec.spring != Undefined and spec.spring.jpa != Undefined and spec.spring.jpa.showSql != Undefined:
            "spring.jpa.show-sql" = _bool(spec.spring.jpa.showSql)
        if spec.spring != Undefined and spec.spring.jpa != Undefined and spec.spring.jpa.openInView != Undefined:
            "spring.jpa.open-in-view" = _bool(spec.spring.jpa.openInView)
        if spec.spring != Undefined and spec.spring.jpa != Undefined and spec.spring.jpa.properties:
            **{"spring.jpa.properties.${key}" = value for key, value in spec.spring.jpa.properties}
    }

    _flyway: {str:str} = {
        if spec.spring != Undefined and spec.spring.flyway != Undefined and spec.spring.flyway.enabled != Undefined:
            "spring.flyway.enabled" = _bool(spec.spring.flyway.enabled)
        if spec.spring != Undefined and spec.spring.flyway != Undefined and spec.spring.flyway.locations:
            "spring.flyway.locations" = _csv(spec.spring.flyway.locations)
        if spec.spring != Undefined and spec.spring.flyway != Undefined and spec.spring.flyway.schemas:
            "spring.flyway.schemas" = _csv(spec.spring.flyway.schemas)
        if spec.spring != Undefined and spec.spring.flyway != Undefined and spec.spring.flyway.table:
            "spring.flyway.table" = spec.spring.flyway.table
        if spec.spring != Undefined and spec.spring.flyway != Undefined and spec.spring.flyway.baselineOnMigrate != Undefined:
            "spring.flyway.baseline-on-migrate" = _bool(spec.spring.flyway.baselineOnMigrate)
        if spec.spring != Undefined and spec.spring.flyway != Undefined and spec.spring.flyway.createSchemas != Undefined:
            "spring.flyway.create-schemas" = _bool(spec.spring.flyway.createSchemas)
    }

    _other_spring: {str:str} = {
        if spec.spring != Undefined and spec.spring.jackson != Undefined and spec.spring.jackson.timeZone:
            "spring.jackson.time-zone" = spec.spring.jackson.timeZone
        if spec.spring != Undefined and spec.spring.jackson != Undefined and spec.spring.jackson.dateFormat:
            "spring.jackson.date-format" = spec.spring.jackson.dateFormat
        if spec.spring != Undefined and spec.spring.jackson != Undefined and spec.spring.jackson.defaultPropertyInclusion:
            "spring.jackson.default-property-inclusion" = spec.spring.jackson.defaultPropertyInclusion
        if spec.spring != Undefined and spec.spring.cache != Undefined and spec.spring.cache.$type:
            "spring.cache.type" = spec.spring.cache.$type
        if spec.spring != Undefined and spec.spring.cache != Undefined and spec.spring.cache.cacheNames:
            "spring.cache.cache-names" = _csv(spec.spring.cache.cacheNames)
        if spec.spring != Undefined and spec.spring.kafka != Undefined and spec.spring.kafka.bootstrapServers:
            "spring.kafka.bootstrap-servers" = _csv(spec.spring.kafka.bootstrapServers)
        if spec.spring != Undefined and spec.spring.kafka != Undefined and spec.spring.kafka.clientId:
            "spring.kafka.client-id" = spec.spring.kafka.clientId
        if spec.spring != Undefined and spec.spring.kafka != Undefined and spec.spring.kafka.consumerGroupId:
            "spring.kafka.consumer.group-id" = spec.spring.kafka.consumerGroupId
        if spec.spring != Undefined and spec.spring.kafka != Undefined and spec.spring.kafka.properties:
            **{"spring.kafka.properties.${key}" = value for key, value in spec.spring.kafka.properties}
        if spec.spring != Undefined and spec.spring.rabbitmq != Undefined and spec.spring.rabbitmq.host:
            "spring.rabbitmq.host" = spec.spring.rabbitmq.host
        if spec.spring != Undefined and spec.spring.rabbitmq != Undefined and spec.spring.rabbitmq.port != Undefined:
            "spring.rabbitmq.port" = str(spec.spring.rabbitmq.port)
        if spec.spring != Undefined and spec.spring.rabbitmq != Undefined and spec.spring.rabbitmq.username:
            "spring.rabbitmq.username" = spec.spring.rabbitmq.username
        if spec.spring != Undefined and spec.spring.rabbitmq != Undefined and spec.spring.rabbitmq.password:
            "spring.rabbitmq.password" = spec.spring.rabbitmq.password
        if spec.spring != Undefined and spec.spring.rabbitmq != Undefined and spec.spring.rabbitmq.virtualHost:
            "spring.rabbitmq.virtual-host" = spec.spring.rabbitmq.virtualHost
    }

    _management: {str:str} = {
        if spec.management != Undefined and spec.management.serverPort != Undefined:
            "management.server.port" = str(spec.management.serverPort)
        if spec.management != Undefined and spec.management.endpointsWebExposureInclude:
            "management.endpoints.web.exposure.include" = _csv(spec.management.endpointsWebExposureInclude)
        if spec.management != Undefined and spec.management.endpointHealthShowDetails:
            "management.endpoint.health.show-details" = spec.management.endpointHealthShowDetails
        if spec.management != Undefined and spec.management.endpointHealthProbesEnabled != Undefined:
            "management.endpoint.health.probes.enabled" = _bool(spec.management.endpointHealthProbesEnabled)
        if spec.management != Undefined and spec.management.metricsTagsApplication:
            "management.metrics.tags.application" = spec.management.metricsTagsApplication
        if spec.management != Undefined and spec.management.securityEnabled != Undefined:
            "management.security.enabled" = _bool(spec.management.securityEnabled)
    }

    _logging: {str:str} = {
        if spec.logging != Undefined and spec.logging.level:
            **{"logging.level.${key}" = value for key, value in spec.logging.level}
        if spec.logging != Undefined and spec.logging.patternConsole:
            "logging.pattern.console" = spec.logging.patternConsole
        if spec.logging != Undefined and spec.logging.fileName:
            "logging.file.name" = spec.logging.fileName
    }

    _springdoc: {str:str} = {
        if spec.springdoc != Undefined and spec.springdoc.apiDocsEnabled != Undefined:
            "springdoc.api-docs.enabled" = _bool(spec.springdoc.apiDocsEnabled)
        if spec.springdoc != Undefined and spec.springdoc.apiDocsPath:
            "springdoc.api-docs.path" = spec.springdoc.apiDocsPath
        if spec.springdoc != Undefined and spec.springdoc.swaggerUiEnabled != Undefined:
            "springdoc.swagger-ui.enabled" = _bool(spec.springdoc.swaggerUiEnabled)
        if spec.springdoc != Undefined and spec.springdoc.swaggerUiPath:
            "springdoc.swagger-ui.path" = spec.springdoc.swaggerUiPath
        if spec.springdoc != Undefined and spec.springdoc.swaggerUiDisableSwaggerDefaultUrl != Undefined:
            "springdoc.swagger-ui.disable-swagger-default-url" = _bool(spec.springdoc.swaggerUiDisableSwaggerDefaultUrl)
        if spec.springdoc != Undefined and spec.springdoc.packagesToScan:
            "springdoc.packages-to-scan" = _csv(spec.springdoc.packagesToScan)
    }

    _security: {str:str} = {
        if spec.security != Undefined and spec.security.oauth2ResourceServerJwtIssuerUri:
            "spring.security.oauth2.resourceserver.jwt.issuer-uri" = spec.security.oauth2ResourceServerJwtIssuerUri
        if spec.security != Undefined and spec.security.oauth2ResourceServerJwtJwkSetUri:
            "spring.security.oauth2.resourceserver.jwt.jwk-set-uri" = spec.security.oauth2ResourceServerJwtJwkSetUri
    }

    _legacy_management: {str:str} = {
        if spec.managementLegacy != Undefined:
            "management.security.enabled" = _bool(spec.managementLegacy.securityEnabled)
            "management.server.port" = str(spec.managementLegacy.serverPort)
            "management.endpoint.health.show-details" = spec.managementLegacy.endpointHealthShowDetails
    }

    _legacy_keycloak: {str:str} = {
        if spec.keycloak != Undefined:
            "keycloak.enabled" = _bool(spec.keycloak.enabled)
            "keycloak.realm" = spec.keycloak.realm
            "keycloak.bearer-only" = _bool(spec.keycloak.bearerOnly)
            "keycloak.resource" = spec.keycloak.resource
            "keycloak.use-resource-role-mappings" = _bool(spec.keycloak.useResourceRoleMappings)
            "keycloak.principal-attribute" = spec.keycloak.principalAttribute
            "keycloak.cors" = _bool(spec.keycloak.cors)
            "keycloak.ssl-required" = spec.keycloak.sslRequired
            "keycloak.public-client" = _bool(spec.keycloak.publicClient)
        if spec.keycloak != Undefined and spec.keycloak.authServerUrl:
            "keycloak.auth-server-url" = spec.keycloak.authServerUrl
    }

    _legacy_clients: {str:str} = {
        if spec.opensearchClient != Undefined:
            "opensearch.https-enabled" = _bool(spec.opensearchClient.httpsEnabled)
            "opensearch.hostname" = spec.opensearchClient.hostname
            "opensearch.path-prefix" = spec.opensearchClient.pathPrefix
            "opensearch.port" = str(spec.opensearchClient.port)
            "opensearch.enable-send-data" = _bool(spec.opensearchClient.enableSendData)
        if spec.opensearchClient != Undefined and spec.opensearchClient.user:
            "opensearch.user" = spec.opensearchClient.user
        if spec.opensearchClient != Undefined and spec.opensearchClient.password:
            "opensearch.password" = spec.opensearchClient.password
        if spec.questdbClient != Undefined:
            "questdb.address" = spec.questdbClient.address
            "questdb.local-zone" = spec.questdbClient.localZone
            **{"questdb.tables.${key}" = value for key, value in spec.questdbClient.questDBTables}
        if spec.scheduler != Undefined:
            "scheduler.time-expression" = spec.scheduler.timeExpression
            **{"scheduler.activations.${key}" = value for key, value in spec.scheduler.activations}
    }

    _legacy_springdoc: {str:str} = {
        if spec.springDoc != Undefined:
            "springdoc.api-docs.path" = spec.springDoc.apiDocs.rootPath
            "springdoc.api-docs.groups.enabled" = _bool(spec.springDoc.apiDocs.enableGroups)
            "springdoc.swagger-ui.disable-swagger-default-url" = _bool(spec.springDoc.swaggerUi.disableSwaggerDefaultUrl)
            "springdoc.swagger-ui.url" = spec.springDoc.swaggerUi.url
            "springdoc.swagger-ui.config-url" = spec.springDoc.swaggerUi.configUrl
        if spec.springDoc != Undefined and spec.springDoc.apiDocConfigGroup:
            **{"springdoc.group-configs.${index}.group" = group.group for index, group in spec.springDoc.apiDocConfigGroup}
            **{"springdoc.group-configs.${index}.packages-to-scan" = group.packagesToScan for index, group in spec.springDoc.apiDocConfigGroup}
        if spec.springDoc != Undefined and spec.springDoc.swaggerUi.groupUrls:
            **{"springdoc.swagger-ui.urls.${index}.name" = group.name for index, group in spec.springDoc.swaggerUi.groupUrls}
            **{"springdoc.swagger-ui.urls.${index}.url" = group.url for index, group in spec.springDoc.swaggerUi.groupUrls}
    }

    _legacy_spring: {str:str} = {
        if spec.moduleSpring != Undefined and spec.moduleSpring.postgres != Undefined:
            "spring.datasource.driver-class-name" = spec.moduleSpring.postgres.driverClassName
            "spring.datasource.username" = spec.moduleSpring.postgres.username
            "spring.datasource.password" = spec.moduleSpring.postgres.password
        if spec.moduleSpring != Undefined and spec.moduleSpring.postgres != Undefined and spec.moduleSpring.postgres.database:
            "spring.datasource.url" = "jdbc:postgresql://${spec.moduleSpring.postgres.namespace}:${spec.moduleSpring.postgres.port}/${spec.moduleSpring.postgres.database}"
        if spec.moduleSpring != Undefined and spec.moduleSpring.postgres != Undefined and spec.moduleSpring.postgres.testOnBorrow != Undefined:
            "spring.datasource.test-on-borrow" = _bool(spec.moduleSpring.postgres.testOnBorrow)
        if spec.moduleSpring != Undefined and spec.moduleSpring.postgres != Undefined and spec.moduleSpring.postgres.validationQuery:
            "spring.datasource.validation-query" = spec.moduleSpring.postgres.validationQuery
        if spec.moduleSpring != Undefined and spec.moduleSpring.oauth2Security != Undefined:
            "spring.security.oauth2.resourceserver.jwt.issuer-uri" = "${spec.moduleSpring.oauth2Security.providerUrl}/realms/${spec.moduleSpring.oauth2Security.realm}"
    }

    _props = spec.properties if spec.properties else {}
    _extra = spec.extraProperties if spec.extraProperties else {}

    _base | _server | _spring | _datasource | _jpa | _flyway | _other_spring | _management | _logging | _springdoc | _security | _legacy_management | _legacy_keycloak | _legacy_clients | _legacy_springdoc | _legacy_spring | _props | _extra
}

render_properties = lambda spec: ApplicationProperties -> str {
    _properties = build_properties(spec)
    "\n".join(["${key}=${value}" for key, value in _properties])
}

