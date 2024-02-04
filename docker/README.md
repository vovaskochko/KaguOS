## Build docker image: ##
```bash
docker build -t kagu  .
```

## Run docker from KaguOS folder and mount it to /KaguOS in container:##
```bash
docker run -v `pwd`:/KaguOS -it --rm kagu bash
```
# Inside container change working dir to /KaguOS
```bash
cd /KaguOS
```
