#!/bin/bash
#
# This script removes local Docker images based on timestamps contained in tags.
# It utilizes the same expiration logic as prune-dtr.rb, but here the expiration age
# is set very small because we want to expire all but the three most recent tags.
#
# Examples:
#   ./prune-local.sh       -- uses default expiration age of 90 days
#   ./prune-local.sh 30    -- set expriation age to 30 DEFAULT_EXPIRATION_AGE_DAYS


# Very simple argument handling
if [[ $# -ne 1 && $# -ne 0 ]]; then
  echo "usage: $0 [age-days]"
  exit 1
fi
RE='^[0-9]+$'
if [[ $# -eq 1 ]] ; then
  if [[ ($1 =~ $RE) ]] ; then
    EXPIRATION_DAYS=$1
  else
    echo "Expiration age in days must be a positive, whole number."
    exit 1
  fi
else
  EXPIRATION_DAYS=90
fi
echo "Using expiration age of $EXPIRATION_DAYS days."

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
