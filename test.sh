#!/bin/bash
# exit when any command fails
set -e

# This script is used to easy start/stop local Hedera Network (with solo).
# It also deploy some pre-requirements for hardhat test like:
#   - create accounts with preconfigured keys and initial balance

WORK_DIR="$(pwd)"
# CONSENSUS_NODE_DIR="../../hiero-consensus-node"
# CONSENSUS_NODE_DIR="../hiero-consensus-node"
CONSENSUS_NODE_DIR="/Users/user/development/hashgraph/hiero-consensus-node"
APP_PROPERTIES_PATH="./application.properties"

export SOLO_BASE_NAME=hedera
export SOLO_CLUSTER_NAME="solo-${SOLO_BASE_NAME}"
export SOLO_NAMESPACE="solo-ns-${SOLO_BASE_NAME}"
export SOLO_CLUSTER_SETUP_NAMESPACE="solo-setup-ns-${SOLO_BASE_NAME}"
export SOLO_DEPLOYMENT="solo-deployment-${SOLO_BASE_NAME}"

# alias f70febf7420398c3892ce79fdc393c1a5487ad27
export TEST_ACCOUNT_ECDSA_PRIVATE_KEY_DER_1=3030020100300706052b8104000a04220420de78ff4e5e77ec2bf28ef7b446d4bec66e06d39b6e6967864b2bf3d6153f3e68
# alias dbe82db504ca6701fbe59e638ceaddbdb691067b
export TEST_ACCOUNT_ECDSA_PRIVATE_KEY_DER_2=3030020100300706052b8104000a04220420748634984b480c75456a68ea88f31609cd3091e012e2834948a6da317b727c04
# alias 84b4d82e6ed64102d0faa6c29bf4e9f541db442f
export TEST_ACCOUNT_ECDSA_PRIVATE_KEY_DER_3=3030020100300706052b8104000a042204203bcb2fbd18610f44eda2bfd58df63d053e2a6b165617a2ef5e5cca079e0c588a
export TEST_ACCOUNT_HBAR_AMOUNT=10000

export SEED_KEY=0x6c6e6727b40c8d4b616ab0d26af357af09337299f09c66704146e14236972106

export RELAY_VERSION=0.73.0-rc1
export MIRROR_NODE_VERSION=0.153.0
export MIRROR_NODE_VALUES_FILE=./mirror-node-values.yaml

# Pectra-preview MN images (Glib's hedera-evm-testing setup).
# Pulled and re-tagged as ${MIRROR_NODE_VERSION} so Solo's chart picks them
# up locally via pullPolicy: IfNotPresent. Set any var to "" to skip its
# override and let Solo pull the official 0.153.0 image instead.
export MIRROR_NODE_WEB3_IMAGE="${MIRROR_NODE_WEB3_IMAGE-docker.io/carlie45/hedera-mirror-web3:0.73.0-pectra-preview-alpha.4}"
export MIRROR_NODE_IMPORTER_IMAGE="${MIRROR_NODE_IMPORTER_IMAGE-docker.io/carlie45/hedera-mirror-importer:0.73.0-pectra-preview-alpha.4}"

######################### functions #########################

check_k8s_context() {
  CURRENT_CONTEXT=$(kubectl config current-context)
  if [ "$CURRENT_CONTEXT" != "kind-${SOLO_CLUSTER_NAME}" ]; then
    printf "Current context: %s is not equals to targeted context: %s\n" "$CURRENT_CONTEXT" "kind-${SOLO_CLUSTER_NAME}"
    exit 1
  fi
}

# solo -> required solo, kubectl, kind
solo_start() {
  # base setup
  kind create cluster -n "${SOLO_CLUSTER_NAME}" || true

  # solo deploy
  check_k8s_context
  solo init --dev
  solo cluster-ref config setup -s "${SOLO_CLUSTER_SETUP_NAMESPACE}" --dev
  solo cluster-ref config connect --cluster-ref kind-${SOLO_CLUSTER_NAME} --context kind-${SOLO_CLUSTER_NAME} --dev
  solo deployment config create -n "${SOLO_NAMESPACE}" --deployment "${SOLO_DEPLOYMENT}" --dev
  solo deployment cluster attach --deployment "${SOLO_DEPLOYMENT}" --cluster-ref kind-${SOLO_CLUSTER_NAME} --num-consensus-nodes 1 --dev
  solo keys consensus generate --gossip-keys --tls-keys --deployment "${SOLO_DEPLOYMENT}" --dev
  # --------- build (./gradlew assemble) in consensus node dir
  # NOTE: Skipped — build CN manually first with JDK 25:
  #   export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-25.jdk/Contents/Home
  #   export PATH="$JAVA_HOME/bin:$PATH"
  #   cd $CONSENSUS_NODE_DIR && ./gradlew assemble
  # cd "${CONSENSUS_NODE_DIR}"
  # ./gradlew assemble
  # cd "${WORK_DIR}"
  # ----------------------------------------------------------------------------
  # network components
  # --------- with local consensus build
  solo consensus network deploy --deployment "${SOLO_DEPLOYMENT}" --application-properties "${APP_PROPERTIES_PATH}" --pvcs true --dev
  solo consensus node setup --deployment "${SOLO_DEPLOYMENT}" -i node1 --local-build-path "${CONSENSUS_NODE_DIR}/hedera-node/data/" --dev
  solo consensus node start --deployment "${SOLO_DEPLOYMENT}" -i node1 --dev

  # Preload Pectra-preview MN images into kind, re-tagged as ${MIRROR_NODE_VERSION}
  # so Solo's chart picks them up locally (IfNotPresent) instead of pulling from gcr.io.
  if [ -n "${MIRROR_NODE_WEB3_IMAGE}" ]; then
    docker pull "${MIRROR_NODE_WEB3_IMAGE}"
    docker image tag "${MIRROR_NODE_WEB3_IMAGE}" "gcr.io/mirrornode/hedera-mirror-web3:${MIRROR_NODE_VERSION}"
    kind load docker-image "gcr.io/mirrornode/hedera-mirror-web3:${MIRROR_NODE_VERSION}" --name "${SOLO_CLUSTER_NAME}"
  fi
  if [ -n "${MIRROR_NODE_IMPORTER_IMAGE}" ]; then
    docker pull "${MIRROR_NODE_IMPORTER_IMAGE}"
    docker image tag "${MIRROR_NODE_IMPORTER_IMAGE}" "gcr.io/mirrornode/hedera-mirror-importer:${MIRROR_NODE_VERSION}"
    kind load docker-image "gcr.io/mirrornode/hedera-mirror-importer:${MIRROR_NODE_VERSION}" --name "${SOLO_CLUSTER_NAME}"
  fi

  solo mirror node add --enable-ingress --pinger --deployment "${SOLO_DEPLOYMENT}" --cluster-ref kind-${SOLO_CLUSTER_NAME} --mirror-node-version="${MIRROR_NODE_VERSION}" --values-file "${MIRROR_NODE_VALUES_FILE}" --dev
  # solo relay node add --deployment "${SOLO_DEPLOYMENT}" -i node1 --dev --values-file relay.yaml
  solo explorer node add --deployment "${SOLO_DEPLOYMENT}" --cluster-ref kind-${SOLO_CLUSTER_NAME} --dev

  # add test accounts to the network
  solo ledger account create --deployment "${SOLO_DEPLOYMENT}" --dev --hbar-amount "${TEST_ACCOUNT_HBAR_AMOUNT}" --private-key --set-alias --ecdsa-private-key "${TEST_ACCOUNT_ECDSA_PRIVATE_KEY_DER_1}"
  solo ledger account create --deployment "${SOLO_DEPLOYMENT}" --dev --hbar-amount "${TEST_ACCOUNT_HBAR_AMOUNT}" --private-key --set-alias --ecdsa-private-key "${TEST_ACCOUNT_ECDSA_PRIVATE_KEY_DER_2}"
  solo ledger account create --deployment "${SOLO_DEPLOYMENT}" --dev --hbar-amount "${TEST_ACCOUNT_HBAR_AMOUNT}" --private-key --set-alias --ecdsa-private-key "${TEST_ACCOUNT_ECDSA_PRIVATE_KEY_DER_3}"

  solo ledger account create --deployment "${SOLO_DEPLOYMENT}" --dev --hbar-amount 1000000000 --private-key --set-alias --ecdsa-private-key "${SEED_KEY}"
}

solo_stop() {
  solo explorer node destroy --cluster-ref=kind-${SOLO_CLUSTER_NAME} --deployment="${SOLO_DEPLOYMENT}" --force --dev || true
  solo mirror-node node destroy --cluster-ref=kind-${SOLO_CLUSTER_NAME} --deployment="${SOLO_DEPLOYMENT}" --force --dev || true
  # solo relay node destroy --cluster-ref=kind-${SOLO_CLUSTER_NAME} --deployment="${SOLO_DEPLOYMENT}" -i node1 --dev || true
  solo consensus node stop --deployment="${SOLO_DEPLOYMENT}" -i node1 --dev || true
  solo consensus network destroy --deployment="${SOLO_DEPLOYMENT}" --force --delete-pvcs --delete-secrets --dev || true
  # next step is hanging and not ending by itself. Do we need it?
  # solo cluster-ref reset --cluster-ref kind-${SOLO_CLUSTER_NAME} -s "${SOLO_CLUSTER_SETUP_NAMESPACE}" --force || true
  solo cluster-ref config disconnect --cluster-ref kind-${SOLO_CLUSTER_NAME} --dev || true
  solo_destroy
}

solo_status() {
  cat ~/.solo/local-config.yaml || true
  echo "-------------------------------------------------------------------------"
  kubectl get pods -n "${SOLO_NAMESPACE}"
}

solo_destroy() {
  kubectl delete namespace "${SOLO_NAMESPACE}" || true
  kubectl delete namespace "${SOLO_CLUSTER_SETUP_NAMESPACE}" || true
  kind delete cluster -n "${SOLO_CLUSTER_NAME}" || true
  rm -rf ~/.solo
}

# Full reset: wipes Solo state, every kind cluster, every helm repo, helm
# caches, port-forwards, and the Pectra-specific Docker images we pulled.
# Use when `solo_stop` / `solo_destroy` leaves you in a half-broken state,
# or when a stale helm repo URL is breaking `solo init`. Safe to run from
# anywhere; failures at each step are swallowed.
solo_nuke() {
  echo ">>> Nuke: graceful Solo teardown (best-effort)"
  solo explorer node destroy --cluster-ref=kind-${SOLO_CLUSTER_NAME} --deployment="${SOLO_DEPLOYMENT}" --force --dev 2>/dev/null || true
  solo mirror-node node destroy --cluster-ref=kind-${SOLO_CLUSTER_NAME} --deployment="${SOLO_DEPLOYMENT}" --force --dev 2>/dev/null || true
  solo consensus node stop --deployment="${SOLO_DEPLOYMENT}" -i node1 --dev 2>/dev/null || true
  solo consensus network destroy --deployment="${SOLO_DEPLOYMENT}" --force --delete-pvcs --delete-secrets --dev 2>/dev/null || true
  solo cluster-ref config disconnect --cluster-ref kind-${SOLO_CLUSTER_NAME} --dev 2>/dev/null || true

  echo ">>> Nuke: kill leftover kubectl port-forwards"
  pkill -f "kubectl.*port-forward" 2>/dev/null || true

  echo ">>> Nuke: delete every kind cluster"
  for c in $(kind get clusters 2>/dev/null); do
    kind delete cluster -n "$c"
  done

  echo ">>> Nuke: wipe Solo state (~/.solo)"
  rm -rf ~/.solo

  echo ">>> Nuke: remove every helm repo"
  for r in $(helm repo list 2>/dev/null | tail -n +2 | awk '{print $1}'); do
    helm repo remove "$r" || true
  done

  echo ">>> Nuke: clear helm caches"
  rm -rf ~/Library/Caches/helm ~/Library/Preferences/helm ~/.config/helm 2>/dev/null || true

  echo ">>> Nuke: remove Pectra-relevant Docker images"
  # Images we pull/load for Solo + the Pectra-preview MN setup. Edit the
  # regex below if you want to keep something (or to nuke more).
  docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
    | grep -E '^(gcr\.io/mirrornode/|docker\.io/carlie45/hedera-mirror-|docker\.io/ikavaldzhiev/hedera-mirror-|ghcr\.io/hiero-ledger/hiero-json-rpc-relay|kindest/node)' \
    | xargs -r docker rmi -f 2>/dev/null || true

  # Uncomment for the truly nuclear option (affects ALL Docker state on this
  # machine — unrelated containers, volumes, networks, build cache):
  # docker system prune -a -f --volumes

  echo ""
  echo ">>> Nuke complete. Verify:"
  echo "  kind get clusters      -> should be empty"
  echo "  helm repo list         -> should error 'no repositories'"
  echo "  ls ~/.solo             -> should error 'No such file'"
  echo "  docker images | grep -E 'mirrornode|hiero|kindest|carlie45'"
  echo "                         -> should be empty"
}

######################### main #########################
case "$1" in

  solo)
    case "$2" in
      start)
        solo_start
        ;;
      stop)
        solo_stop
        ;;
      status)
        solo_status
        ;;
      destroy)
        solo_destroy
        ;;
      nuke)
        solo_nuke
        ;;
    	*)
    		echo "Usage: [start|stop|status|destroy|nuke]"
    		exit 1
    		;;
    esac
    ;;

	*)
		echo "Usage: [solo|node]"
		exit 1
		;;
esac
