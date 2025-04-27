"""
Combination of kernel, stack and site configurations that will generate a concrete version for a concrete tenant of an OCI artifact
"""

schema Release:
    project: Project
    name: str    
    version: str