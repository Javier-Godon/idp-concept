import framework.models.project
import video_streaming.kernel.configurations

video_streaming_project = project.Project {
    name = "Video Streaming"
    description = "video streaming using apache kafka"
    configurations = configurations._video_streaming_kernel_configurations
}
