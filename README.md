## Logstash BOSH Release

```
./add-blobs.sh

bosh create-release --name=cf-logging --force --timestamp-version --tarball=/tmp/cf-logging-boshrelease.tgz
bosh upload-release
```



To create a final release:

```
bosh create-release --name=logstash --version=1 --tarball=/tmp/logstash-boshrelease.tgz
```


To interpolate a final manifest with a cloud-id and a test pipeline.


```
bosh int manifests/logstash.yml -o manifests/add-cloud-id.yml -o manifests/pipelines/add-test.yml -o manifests/add-settings.yml  --var-file pipeline=manifests/pipelines/test.conf --vars-file manifests/secrets.yml --vars-file manifests/settings.yml
```


```
bosh int manifests/logstash.yml -o manifests/add-cloud-id.yml -o manifests/pipelines/add-logstash.yml -o manifests/add-settings.yml  --var-file pipeline=manifests/pipelines/logstash.conf --vars-file manifests/secrets.yml --vars-file manifests/settings.yml
```
