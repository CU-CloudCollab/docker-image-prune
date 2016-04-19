# docker_image_prune

This repo contains functionality to list and delete images from a Docker Trusted Repository based on date stamps embedded in image tags.

## Prerequisites

These functions operates on DTR images labeled as follows [ID]-[MMDDYYYY]-[HHMMSS]. Here [ID] is a container ID, [MMDDYYYY] is the month, day, and year and [HHMMSS] is the hour, minute, and seconds. The assumption is that an image labeled as such was built at the given time. An example:  d60015f3c0-04172016-172400

Docker authentication must be configured (as for Docker command line commands) in ~/.docker/config.json.

## Command line

### Usage
```
$ ./go.rb --help
Remove Docker Trusted Repository images that are older than n days based on timestamp in tags.

Usage: go.rb [options]
    -n, --namespace namespace        (required) DTR namespace (e.g., cs)
    -r, --repo respository           (required) DTR respository name (e.g., helloworld)
    -x, --expiration age             maximum age in days (default = 90)
    -d, --dry-run                    simulate pruning (defaults to false)
    -h, --help                       displays this help
```

### Examples

`./go.rb --namespace pea1 --repo hello --expiration 30 --dry-run`

Target repository is https://dtr.cucloud.net/repositories/pea1/hello. Images with timestamps in tags that are more than 30 days ago are targeted for deletion. However, no tags will actually be deleted because of the `--dry-run` parameter.

`./go.rb --namespace cs --repo apache`

Target repository is https://dtr.cucloud.net/repositories/cs/apache. Images with timestamps in tags that are more than 90 days (i.e., the default) ago are targeted for deletion.
