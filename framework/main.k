import models.stack
import models.component
import models.accessory

video_streaming = stack.Stack {
    name = "video_streaming_dev"
    components = [
        component.Component {
            type: "APPLICATION"
            name: "producer"
            manifests: [{}]
        }
    ]
    accesories = [
        accessory.Accessory {
            type: "CRD"
            name: "producer"
            manifests: [{}]
        }
    ]
}
