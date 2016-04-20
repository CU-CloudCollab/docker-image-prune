#!/bin/bash
#
# This script removes local Docker images based on timestamps contained in tags.
# It utilizes the same expiration logic as prune-dtr.rb, but here the expiration age
# is set very small because we want to expire all but the three most recent tags.
#
EXPIRATION_DAYS=90

# Get the list of unique repos that are present locally
for REPO in $(docker images --filter "dangling=false" --format '{{.Repository}}' | uniq)
do
  echo "Processing $REPO..."

  # Get the list of tags for the repo and make sure they have the right timestamp format.
  # Put the list in a format that is amenable to Ruby.
  OUTPUT=""
  for TAG in $(docker images --format '{{.Tag}}' $REPO | grep '.*-[0-9]\{8\}.[0-9]\{6\}')
  do
    OUTPUT="$OUTPUT'$TAG',"
  done

  # Call the Ruby function that implements the tag expiration rules.
  # Provide a customized expiration age in days.
  for TAG in $(ruby -r ./docker_image_prune.rb -e "puts DockerImagePrune.determine_expired_tags([$OUTPUT],$EXPIRATION_DAYS)")
  do
    echo "Removing $REPO:$TAG"
    docker rmi $REPO:$TAG
  done
  echo "========================="
done
