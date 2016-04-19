# docker_image_prune

This repo contains functionality to list and delete images from a Docker Trusted Repository based on date stamps embedded in image tags.

This functionality does not directly delete a DTR image. In actuallity, this functionality simply removes the tag for an image. Then, when the DTR performs garbage collection (typically daily), the associated image will be removed if no other images depend on it.

## Prerequisites

These functions operates on DTR images labeled as follows [ID]-[MMDDYYYY]-[HHMMSS]. Here [ID] is a container ID, [MMDDYYYY] is the month, day, and year and [HHMMSS] is the hour, minute, and seconds. The assumption is that an image labeled as such was built at the given time. An example tag:  d60015f3c0-04172016-172400

Docker authentication must be configured (as for Docker command line commands) in ~/.docker/config.json.

## Failsafes

If there would be fewer than three images in a repository tagged with timestamps after pruning, this code will skip the removal of expired images so that the latest three images remain, regardless of expiration status.

## Command line

### Options

`--namespace <namespace>` targets the specified DTR namespace; **required**

`--no-prune` (default) advises on what would happen, but does not alter the DTR at all

`--prune` actually performs the tag deletion

`--expiration <days>` changes the expiration period from default 90 days to <days>

### Usage
```
$ ./go.rb --help
Remove Docker Trusted Repository images that are older than n days based on timestamp in tags.

Usage: go.rb [options]
    -n, --namespace namespace        (required) DTR namespace (e.g., cs)
    -a, --expiration age             maximum age in days (default = 90)
    -p, --prune                      prune the images (defaults to false, i.e. a dry run)
    -x, --no-prune                   prune the images (defaults to false, i.e. a dry run)
    -h, --help                       displays this help
```

### Examples

`./go.rb --namespace pea1 --expiration 30 --no-prune`

Target namespace is https://dtr.cucloud.net/repositories/pea1/. Images with timestamps in tags that are more than 30 days ago are targeted for deletion. However, no tags will actually be deleted because of the `--no-prune` parameter.

`./go.rb --namespace cs  --expiration 90 --prune`

Target namespace is https://dtr.cucloud.net/repositories/cs. Images with timestamps in tags that are more than 90 days (i.e., the default) ago are targeted for deletion.

## Dependencies

* Gems
  * rest-client
* Docker Trusted Repository
  * version 1.4.3
* Docker Trusted Repository API
  * version 0
