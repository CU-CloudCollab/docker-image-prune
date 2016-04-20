#!/bin/bash

# Create some tagged images to test against.
# If using a private DTR, the target repos must already be created.

docker pull hello-world

TARGET="dtr.cucloud.net/pea1/hello-world"
ID="hello-world"

docker tag $ID $TARGET:"5086d6d2a44b-01012015-010000"
docker push $TARGET:"5086d6d2a44b-01012015-010000"

docker tag $ID $TARGET:"5086d6d2a44b-12012015-010000"
docker push $TARGET:"5086d6d2a44b-12012015-010000"

docker tag $ID $TARGET:"5086d6d2a44b-01012016-010000"
docker push $TARGET:"5086d6d2a44b-01012016-010000"

docker tag $ID $TARGET:"5086d6d2a44b-02012016-010000"
docker push $TARGET:"5086d6d2a44b-02012016-010000"

docker tag $ID $TARGET:"5086d6d2a44b-03012016-010000"
docker push $TARGET:"5086d6d2a44b-03012016-010000"

docker tag $ID $TARGET:"5086d6d2a44b-04012016-010000"
docker push $TARGET:"5086d6d2a44b-04012016-010000"

docker tag $ID $TARGET:"5086d6d2a44b-05012016-010000"
docker push $TARGET:"5086d6d2a44b-05012016-010000"

######################################################

TARGET="dtr.cucloud.net/pea1/hello"

docker tag $ID $TARGET:"5086d6d2a44b-01012015-010000"
docker push $TARGET:"5086d6d2a44b-01012015-010000"

docker tag $ID $TARGET:"5086d6d2a44b-12012015-010000"
docker push $TARGET:"5086d6d2a44b-12012015-010000"

docker tag $ID $TARGET:"5086d6d2a44b-01012016-010000"
docker push $TARGET:"5086d6d2a44b-01012016-010000"

docker tag $ID $TARGET:"5086d6d2a44b-02012016-010000"
docker push $TARGET:"5086d6d2a44b-02012016-010000"

docker tag $ID $TARGET:"5086d6d2a44b-03012016-010000"
docker push $TARGET:"5086d6d2a44b-03012016-010000"

docker tag $ID $TARGET:"5086d6d2a44b-04012016-010000"
docker push $TARGET:"5086d6d2a44b-04012016-010000"

docker tag $ID $TARGET:"5086d6d2a44b-05012016-010000"
docker push $TARGET:"5086d6d2a44b-05012016-010000"
