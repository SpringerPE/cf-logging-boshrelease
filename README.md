## Logstash BOSH Release

```
./add-blobs.sh

bosh create-release --name=logstash --force --timestamp-version --tarball=/tmp/logstash-boshrelease.tgz
bosh upload-release
bosh -n -d logstash deploy manifest/logstash.yml --var-file logstash.conf=manifest/logstash.conf --no-redact
```



To create a final release:

```
bosh create-release --name=logstash --version=1 --tarball=/tmp/logstash-boshrelease.tgz
bosh upload-release
```


To interpolate a final manifest with a cloud-id and a test pipeline.


```
bosh-cli int logstash.yml -o add-cloud-id.yml -o pipelines/add-test.yml -o add-settings.yml  --var-file test=pipelines/test.conf --vars-file secrets.yml --vars-file settings.yml
```
