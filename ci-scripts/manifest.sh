#! /bin/bash

# Globals
FAILED="false"

# Ingest cli variables
## Parse input ##
NAME1=$1
NAME2=$2
TYPE=$3
REVERT_PIPELINE_ID=$4
IS_ROLLING=$5
PULL_BRANCH=${SANITIZED_BRANCH}

# Determine if this is a private or public build
if [[ "${CI_COMMIT_REF_NAME}" == release/* ]] || [[ "${CI_COMMIT_REF_NAME}" == "develop" ]]; then
  ENDPOINT="core-${NAME1}-${NAME2}"
else
  ENDPOINT="core-${NAME1}-${NAME2}-private"
fi

# Determine if this is a rolling build
if [ "${CI_PIPELINE_SOURCE}" == "schedule" ]; then
  SANITIZED_BRANCH=${SANITIZED_BRANCH}-rolling
fi

# Determine if we are doing a reversion
if [ ! -z "${REVERT_PIPELINE_ID}" ]; then
  # If we are reverting modify the pipeline ID to the one passed
  CI_PIPELINE_ID=${REVERT_PIPELINE_ID}
  if [ "${IS_ROLLING}" == "true" ]; then
    SANITIZED_BRANCH=${SANITIZED_BRANCH}-rolling
  fi
fi

# Check test output
if [ -z "${REVERT_PIPELINE_ID}" ]; then
  apk add curl
  if [ "${TYPE}" == "multi" ]; then
    ARCHES=("x86_64" "aarch64")
  else
    ARCHES=("x86_64")
  fi
  for ARCH in "${ARCHES[@]}"; do

    # Determine test status
    STATUS=$(curl -sL https://kasm-ci.s3.amazonaws.com/${CI_COMMIT_SHA}/${ARCH}/kasmweb/image-cache-private/${ARCH}-core-${NAME1}-${NAME2}-${PULL_BRANCH}-${CI_PIPELINE_ID}/ci-status.yml | awk -F'"' '{print $2}')
    if [ "${STATUS}" == "PASS" ]; then
      STATE=success
    else
      STATE=failed
      FAILED="true"
    fi

    # Ping gitlab api with link output
    curl --request POST --header "PRIVATE-TOKEN:${GITLAB_API_TOKEN}" "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/statuses/${CI_COMMIT_SHA}?state=${STATE}&name=core-${NAME1}-${NAME2}_${ARCH}&target_url=https://kasm-ci.s3.amazonaws.com/${CI_COMMIT_SHA}/${ARCH}/kasmweb/image-cache-private/${ARCH}-core-${NAME1}-${NAME2}-${PULL_BRANCH}-${CI_PIPELINE_ID}/index.html"

  done
fi

# Fail job and go no further if tests did not pass
if [ "${FAILED}" == "true" ]; then
  exit 1
fi

# Manifest for multi pull and push for single arch
if [ "${TYPE}" == "multi" ]; then

  # Pull images from cache repo
  docker pull ${ORG_NAME}/image-cache-private:x86_64-core-${NAME1}-${NAME2}-${PULL_BRANCH}-${CI_PIPELINE_ID}
  docker pull ${ORG_NAME}/image-cache-private:aarch64-core-${NAME1}-${NAME2}-${PULL_BRANCH}-${CI_PIPELINE_ID}

  # Tag images to live repo
  docker tag \
    ${ORG_NAME}/image-cache-private:x86_64-core-${NAME1}-${NAME2}-${PULL_BRANCH}-${CI_PIPELINE_ID} \
    ${ORG_NAME}/${ENDPOINT}:x86_64-${SANITIZED_BRANCH}
  docker tag \
    ${ORG_NAME}/image-cache-private:aarch64-core-${NAME1}-${NAME2}-${PULL_BRANCH}-${CI_PIPELINE_ID} \
    ${ORG_NAME}/${ENDPOINT}:aarch64-${SANITIZED_BRANCH}

  # Push arches to live repo
  docker push ${ORG_NAME}/${ENDPOINT}:x86_64-${SANITIZED_BRANCH}
  docker push ${ORG_NAME}/${ENDPOINT}:aarch64-${SANITIZED_BRANCH}

  # Manifest to meta tag
  docker manifest push --purge ${ORG_NAME}/${ENDPOINT}:${SANITIZED_BRANCH} || :
  docker manifest create ${ORG_NAME}/${ENDPOINT}:${SANITIZED_BRANCH} ${ORG_NAME}/${ENDPOINT}:x86_64-${SANITIZED_BRANCH} ${ORG_NAME}/${ENDPOINT}:aarch64-${SANITIZED_BRANCH}
  docker manifest annotate ${ORG_NAME}/${ENDPOINT}:${SANITIZED_BRANCH} ${ORG_NAME}/${ENDPOINT}:aarch64-${SANITIZED_BRANCH} --os linux --arch arm64 --variant v8
  docker manifest push --purge ${ORG_NAME}/${ENDPOINT}:${SANITIZED_BRANCH}

# Single arch image just pull and push
else

  # Pull image
  docker pull ${ORG_NAME}/image-cache-private:x86_64-core-${NAME1}-${NAME2}-${PULL_BRANCH}-${CI_PIPELINE_ID}

  # Tage image
  docker tag \
    ${ORG_NAME}/image-cache-private:x86_64-core-${NAME1}-${NAME2}-${PULL_BRANCH}-${CI_PIPELINE_ID} \
    ${ORG_NAME}/${ENDPOINT}:${SANITIZED_BRANCH}

  # Push image
  docker push ${ORG_NAME}/${ENDPOINT}:${SANITIZED_BRANCH}

fi
