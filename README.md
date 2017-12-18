# docker-image-prune

This repo contains logic to remove Docker images from either a Docker machine, or a Docker Trusted Repository. Logic about which images to expire is based on a date-time stamp embedded in image tags.

This code does not directly delete a DTR image. In actuality, this functionality simply removes the tag for an image on the DTR. Then, when the DTR performs garbage collection (typically daily), the associated image will be removed if no other images depend on it.

Likewise, this code does not directly delete a local Docker image. Instead it simply removes a tag. If that tag is the last for a particular image, then the image will be removed from the connected Docker environment.

## Prerequisites

These functions operate on images labeled as follows [ID]-[MMDDYYYY]-[HHMMSS]. Here [ID] is an arbitrart ID, [MMDDYYYY] is the month, day, and year and [HHMMSS] is the hour, minute, and seconds. The assumption is that an image labeled as such was built at the given time. An example tag:  d60015f3c0-04172016-172400

Docker authentication must be configured (as for Docker command line commands) in ~/.docker/config.json.

## Failsafes

If there would be fewer than three images in a repository tagged with timestamps after pruning, this code will skip the removal of expired images so that the latest three images remain, regardless of expiration status.

# Removing DTR Tags

## prune-dtr.rb

This Ruby code is a wrapper for the DockerImagePrune class contained in docker_image_prune.rb. prune-dtr.rb handles option parsing, while DockerImagePrune implements communication with a DTR as well as tag expiration logic.

### Options

 `--namespace <namespace>` targets the specified DTR namespace; **required**
`--no-prune` (default) advises on what would happen, but does not alter the DTR at all
`--prune` actually performs the tag deletion
`--expiration <days>` changes the expiration period from default 90 days to <days>

### Usage
```
$ ./prune-dtr.rb --help
Remove Docker Trusted Repository images that are older than n days based on timestamp in tags.

Usage: prune-dtr.rb [options]
    -n, --namespace namespace        (required) DTR namespace (e.g., cs)
    -a, --expiration age             maximum age in days (default = 90)
    -p, --prune                      prune the images (defaults to false, i.e. a dry run)
    -x, --no-prune                   prune the images (defaults to false, i.e. a dry run)
    -h, --help                       displays this help
```

### Examples

`./prune-dtr.rb.rb --namespace pea1 --expiration 30 --no-prune`

Target namespace is https://dtr.cucloud.net/repositories/pea1/. Images with timestamps in tags that are more than 30 days ago are targeted for deletion. However, no tags will actually be deleted because of the `--no-prune` parameter.

`./prune-dtr.rb --namespace cs  --expiration 90 --prune`

Target namespace is https://dtr.cucloud.net/repositories/cs. Images with timestamps in tags that are more than 90 days (i.e., the default) ago are targeted for deletion.

### Setting Up Tests

`go-test-setup-dtr.sh` is a Bash script that tags images with a tag in the timestap format described above and pushes them to a DTR. It is easily modified to point to a different DTR or DTR repository.

# Removing Local Tags/Images

## prune-local.sh

This script uses Docker CLI commands and tag expiration logic from the Ruby DockerImagePrune class contained in docker_image_prune.rb. It removes tags from local Docker environment to recover disk space.

### Usage

`usage: ./prune-local.sh [age-days]`

**Examples**

`./prune-local.sh` prunes with expiration age of default 90 days

`./prune-local.sh 7` prunes with expiration age of 7 days

### Setting Up Tests

`go-test-setup-local.sh` is a Bash script that pulls a Docker image and then tags it with timestamp tags as described above.

# Dependencies

* Gems
  * rest-client
* Docker Trusted Repository
  * version 2.1.7
* Docker Trusted Repository API
  * version 0(?)

# Future Changes

Besides the parameter options listed above, the code is written to be fairly easily extensible to different DTR hosts, tag datetime formats, and minimum images to keep.
