# idp-concept
internal development portal POC

```
chmod +x <local_path_to_project>/idp-concept/platform_cli/koncept
```

```
mkdir -p ~/.local/bin
ln -s <local_path_to_project>/idp-concept/platform_cli/koncept ~/.local/bin/koncept
```

then you can execute:

from for example:

from idp-concept/projects/video_streaming/releases/helmfile/berlin/v1_0_0_berlin:

```
koncept render helmfile
```

from idp-concept/projects/video_streaming/pre_releases/gitops/site_one/generators/kafka_video_consumer_mongodb_python/dev

```
koncept render argocd
```

from idp-concept/projects/video_streaming/releases/kusion/berlin/v1_0_0_berlin/default

```
koncept render kusion
```




