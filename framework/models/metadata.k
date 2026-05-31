"""
Common IDP metadata schemas.

These optional fields capture common platform-catalog concepts used by IDPs
such as Backstage, Humanitec, Port, Cortex, OpsLevel, and internal developer
portals: ownership, lifecycle, taxonomy, links, contacts, labels, annotations,
SLO tier, data classification, cost center, and runbook references.
"""

schema Link:
    title: str
    url: str
    icon?: str
    $type?: str

    check:
        len(title) > 0, "link title must not be empty"
        len(url) > 0, "link url must not be empty"

schema Contact:
    name?: str
    email?: str
    url?: str
    $type?: str

    check:
        name != Undefined or email != Undefined or url != Undefined, "contact must define name, email, or url"

schema Metadata:
    """Portable metadata that can be attached to core IDP entities."""
    displayName?: str
    description?: str
    owner?: str
    team?: str
    system?: str
    domain?: str
    lifecycle?: str
    tier?: str
    sloTier?: str
    criticality?: str
    dataClassification?: str
    costCenter?: str
    runbook?: str
    repository?: str
    documentation?: str
    support?: str
    tags?: [str]
    labels?: {str:str}
    annotations?: {str:str}
    links?: [Link]
    contacts?: [Contact]

