# The following variables need to be added to `application.properties`
# consensus.handle.maxFollowingRecords=256
#
# The following environment variables were set in the Relay configmap
# RATE_LIMIT_DISABLED: "true"
# MAX_TRANSACTION_FEE_THRESHOLD: "100000000"

UV=uv
SOLO=solo
SOLO_DEPLOYMENT=solo-one-shot

FORK=Prague
RPC_URL=http://localhost:7546/
SEED_KEY=0x6c6e6727b40c8d4b616ab0d26af357af09337299f09c66704146e14236972106

FORKS=frontier homestead byzantium constantinople istanbul berlin paris shanghai cancun

.PHONY: all clean fund-seed-account

all: $(FORKS:%=tests/%/report.html)

$(FORKS): %: tests/%/report.html

# To avoid hardcoding the chain-id https://github.com/ethereum/execution-spec-tests/issues/2246
#
# --transaction-gas-limit
#   Some tests use `Environment().gas_limit` when setting the gas limit for transactions.
#   This value needs to be less than or equal to the Relay's `MAX_TRANSACTION_FEE_THRESHOLD` setting for the tests to pass.
#   The default value for `MAX_TRANSACTION_FEE_THRESHOLD` is `15_000_000`.
#
# --tx-wait-timeout
#  This timeout is used when waiting for a transaction to be included in a block.
#  On a local Solo environment this is fairly quick.
#  However, when the transaction is sent to the CN but fails,
#  the client will still wait for the timeout (default 60 seconds) before raising an error.
#  Using a lower timeout here will make the tests fail faster.
tests/%/report.html: tests/%/*/test_*.py
	-$(UV) run execute remote -rA --verbose --fork=$(FORK) --rpc-endpoint=$(RPC_URL) --rpc-seed-key=$(SEED_KEY) --rpc-chain-id 298 \
		--html=$@ --self-contained-html \
		--sender-funding-txs-gas-price='710 gwei' \
		--default-gas-price=710_000_000_000 \
		--sender-fund-refund-gas-limit=1_000_000 \
		--seed-account-sweep-amount='70000 ether' \
		--eoa-fund-amount-default=8_000_000_000_000_000_000_000 \
		--tx-wait-timeout 15 \
		$(PYTEST_OPTS) tests/$*

clean:
	-rm -v tests/*/report.html

solo-start:
	$(SOLO) one-shot single deploy --deployment $(SOLO_DEPLOYMENT)

solo-stop:
	$(SOLO) one-shot single destroy --deployment $(SOLO_DEPLOYMENT)

fund-seed-account: HBAR_AMOUNT=1000000000
fund-seed-account: ADDRESS=$(shell cast wallet address $(SEED_KEY))
fund-seed-account:
	@echo "Funding seed account $(ADDRESS) with $(HBAR_AMOUNT) HBARs using Solo deployment $(SOLO_DEPLOYMENT)"
	$(SOLO) ledger account update --account-id $(ADDRESS) --deployment $(SOLO_DEPLOYMENT) --hbar-amount $(HBAR_AMOUNT)

relay-config:
	$(SOLO) relay node upgrade --values-file relay.yaml --deployment $(SOLO_DEPLOYMENT)

relay-restart:
	kubectl rollout restart deployment relay-1
	kubectl rollout status deployment relay-1 --timeout=60s
	$(SOLO) relay node upgrade --deployment $(SOLO_DEPLOYMENT)
