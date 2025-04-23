import models.component
import models.accessory

schema Stack:
    name: str
    components: [component.Component]
    accesories?: [accessory.Accessory]

