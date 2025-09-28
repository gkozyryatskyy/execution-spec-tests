# Solo instance started with
#
# solo quick-start single deploy
#
# To add more funds to an account, use the command below, replacing the account ID and deployment file as needed.
#
# solo account update --account-id 0.0.1018 --deployment $DEPLOYMENT --hbar-amount 1000000000
#

# The following environment variables were set in the Relay configmap
# MAX_TRANSACTION_FEE_THRESHOLD: "22500000"                                         
# RATE_LIMIT_DISABLED: "true"                                                       

UV=~/.local/bin/uv

FORK=Cancun
RPC_URL=http://localhost:7546/
SEED_KEY=0x6c6e6727b40c8d4b616ab0d26af357af09337299f09c66704146e14236972106

FORKS=frontier homestead byzantium constantinople istanbul berlin paris shanghai cancun

.PHONY: all clean pods relay-edit relay-restart

all: $(FORKS:%=tests/%/report.html)

$(FORKS): %: tests/%/report.html

tests/%/report.html: CHAIN_ID=$(shell cat .chain-id)
tests/%/report.html: tests/%/*/test_*.py .chain-id
	$(UV) run execute remote -rA --verbose --fork=$(FORK) --rpc-endpoint=$(RPC_URL) --rpc-seed-key=$(SEED_KEY) --rpc-chain-id $(CHAIN_ID) \
		--html=$@ --self-contained-html \
		--sender-funding-txs-gas-price 710000000000 \
		--default-gas-price 710000000000 \
		--sender-fund-refund-gas-limit 1000000 \
		--seed-account-sweep-amount=70000000000000000000000 \
		--eoa-fund-amount-default=8000000000000000000000 $(PYTEST_OPTS) tests/$*

clean:
	-rm -v tests/*/report.html .chain-id

# Determines the network's chain ID from the JSON-RPC url
# Using `curl` and `jq` instead of `cast` to avoid dependency on Foundry
# Using Foundry's `cast` command
# cast chain-id --rpc-url $(RPC_URL) > .chain-id
.chain-id:
	echo $$((`curl --request POST --url $(RPC_URL) --data '{ "method":"eth_chainId", "id":1, "jsonrpc":"2.0"}' | jq --raw-output .result`)) > .chain-id

#
# Solo commands to view and manage deployment nodes
#
SOLO=$(shell kubectl get namespaces | grep solo-setup --invert-match | grep "solo-" | cut -f 1 -d " ")

pods:
	kubectl get pods -n $(SOLO)

relay-edit:
	kubectl edit configmap -n $(SOLO) relay-node1

relay-restart:
	kubectl rollout restart deployment relay-node1 -n $(SOLO)
