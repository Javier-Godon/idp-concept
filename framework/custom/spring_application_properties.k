schema ApplicationProperties:
    applicationName: str
    serverPort: int
    contextPath: str = "/${applicationName}"
    moduleSpring?: ModuleSpring 
    jwtAuthKcClientId?: str = "frontend"
    flyway?: SubModuleFlyway
    keycloak?: ModuleKeycloak
    management?: ModuleManagement
    springDoc?: ModuleSpringDoc
    opensearchClient?: ModuleOpensearchClient
    questdbClient?: ModuleQuestDBClient  
    scheduler?: scheduler

schema ModuleSpring:
    postgres?: SubModulePostgres
    questdb?: SubModuleQuestDB
    flyway?: SubModuleFlyway
    oauth2Security?: SubModuleOauth2Security

schema SubModulePostgres:
    driverClassName: str ="org.postgresql.Driver"
    namespace: str
    username: str
    password: str
    testOnBorrow?: bool
    validationQuery?: str

schema SubModuleQuestDB:
    driverClassName: str ="org.postgresql.Driver"
    namespace: str
    username: str
    password: str


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
    authServerUrl: str = "https://blue-env.com/auth"
    realm: str
    bearerOnly: bool = True
    resource: str = "frontend"
    useResourceRoleMappings: bool = True
    principalAttribute: str "preferred-username"
    cors: bool = False
    sslRequired: str = "none"
    publicClient: bool = True

schema ModuleManagement:
    securityEnabled: bool = False
    serverPort: int
    endpointHealthShowDetails: str = "always"

schema ModuleSpringDoc:
    apiDocs: ApiDocs
    apiDocConfigGroup?: [ApiDocConfigGroup]
    swaggerUi: SwaggerUi

schema SwaggerUi:
    disableSwaggerDefaultUrl: bool = True
    url: str
    configUrl: str = url + "/swagger-config"
    groupUrls: [GroupUrl]

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
    user: str = "admin"
    pass: str = "pass"
    enableSendData: bool = True

schema ModuleQuestDBClient:
    address: str
    localZone: str = "Europe/Madrid"
    questDBTables: {str:str}


schema scheduler:
    timeExpression: str
    activations: {str:str}