import framework.models.project
import .configurations

video_streaming_project = project.Project {
    name = "Video Streaming"
    description = "video streaming using apache kafka"
    configurations = configurations._video_streaming_kernel_configurations
}
