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

.PHONY: all clean solo-pods relay-edit relay-restart

all: $(FORKS:%=tests/%/report.html)

$(FORKS): %: tests/%/report.html

# https://github.com/ethereum/execution-spec-tests/issues/2246
tests/%/report.html: tests/%/*/test_*.py
	$(UV) run execute remote -rA --verbose --fork=$(FORK) --rpc-endpoint=$(RPC_URL) --rpc-seed-key=$(SEED_KEY) --rpc-chain-id 298 \
		--html=$@ --self-contained-html \
		--sender-funding-txs-gas-price='710 gwei' \
		--default-gas-price=710_000_000_000 \
		--sender-fund-refund-gas-limit=1_000_000 \
		--seed-account-sweep-amount='70000 ether' \
		--eoa-fund-amount-default=8_000_000_000_000_000_000_000 \
		--transaction-gas-limit=15_000_000 \
		$(PYTEST_OPTS) tests/$*

clean:
	-rm -v tests/*/report.html

#
# Solo commands to view and manage deployment nodes
#
SOLO=$(shell kubectl get namespaces | grep solo-setup --invert-match | grep "solo-" | cut -f 1 -d " ")

solo-pods:
	kubectl get pods --namespace $(SOLO)

relay-edit:
	kubectl edit configmap --namespace $(SOLO) relay-node1

relay-restart:
	kubectl rollout restart deployment relay-node1 --namespace $(SOLO)
