import framework.models.modules.accessory as accessory

schema MongoDBSingleInstanceModule(accessory.Accessory):
    kind = "CRD"
    leaders = [accessory.AccessoryLeader {
        name = "Deployment"
        kind = "Deployment"
        apiVersion = "apps/v1"
        namespace = namespace
    }]
    manifests = [
        {
            apiVersion = "apps/v1"
            kind = "Deployment"
            metadata = {
                name = name
                namespace = namespace
            }
            spec = {
                selector = {
                    matchLabels = {
                        app = name
                    }
                }
                replicas = 1
                strategy = {
                    $type = "RollingUpdate"
                    rollingUpdate = {
                        maxSurge = 1
                        maxUnavailable = 1
                    }
                }
                minReadySeconds = 5
                template = {
                    metadata = {
                        labels = {
                            app = name
                        }
                    }
                    spec = {
                        containers = [
                            {
                                name = name
                                image = "${asset.image}:${asset.version}"
                                resources = {
                                    limits = {
                                        memory = "4Gi"
                                        cpu = "1000m"
                                    }
                                    requests = {
                                        memory = "2Gi"
                                        cpu = "500m"
                                    }
                                }
                                imagePullPolicy = "Always"
                                env = [
                                    {
                                        name = "MONGO_INITDB_ROOT_USERNAME"
                                        value = "admin"
                                    }
                                    {
                                        name = "MONGO_INITDB_ROOT_PASSWORD"
                                        value = "admin"
                                    }
                                ]
                                ports = [
                                    {
                                        containerPort = 27017
                                        name = "mongodb"
                                    }
                                ]
                                volumeMounts = [
                                    {
                                        name = "${name}-pv"
                                        mountPath = "/data/db"
                                    }
                                ]
                            }
                        ]
                        volumes = [
                            {
                                name = "${name}-pv"
                                persistentVolumeClaim = {
                                    claimName = "${name}-pvc"
                                }
                            }
                        ]
                    }
                }
            }
        }
        {
            apiVersion = "v1"
            kind = "Service"
            metadata = {
                name = name
                labels = {
                    app = name
                }
                namespace = namespace
            }
            spec = {
                selector = {
                    app = name
                }
                ports = [
                    {
                        name = "mongodb"
                        port = 27017
                        nodePort = 30332
                    }
                ]
                $type = "NodePort"
            }
        }
    ]

