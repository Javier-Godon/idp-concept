"""
Common schemas for Kubernetes resource fields.
Provides type-safe alternatives to `any` for commonly used structures.
"""

schema KeySelector:
    name: str
    key: str

schema EnvVarSource:
    secretKeyRef?: KeySelector
    configMapKeyRef?: KeySelector

    check:
        secretKeyRef or configMapKeyRef, "envVarSource must have either secretKeyRef or configMapKeyRef"
        not (secretKeyRef and configMapKeyRef), "envVarSource cannot have both secretKeyRef and configMapKeyRef"

schema EnvVar:
    """Kubernetes environment variable specification."""
    name: str
    value?: str
    valueFrom?: EnvVarSource

    check:
        value is not Undefined or valueFrom is not Undefined, "env var must have either value or valueFrom"
        not (value is not Undefined and valueFrom is not Undefined), "env var cannot have both value and valueFrom"
