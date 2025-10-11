minikube start -p crossplane-v2 \
  --container-runtime=containerd \
  --cpus=8 \       
  --memory=16g \
  --disk-size=60g


minikube addons enable storage-provisioner-rancher -p crossplane-v2  