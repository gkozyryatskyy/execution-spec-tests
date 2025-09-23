# Solo instance started with
#
# solo quick-start single deploy
#
# To add more funds to an account, use the command below, replacing the account ID and deployment file as needed.
#
# solo account update --account-id 0.0.1018 --deployment $DEPLOYMENT --hbar-amount 1000000000
#

UV=~/.local/bin/uv
JUNIT2HTML=~/.local/bin/junit2html

FORK=Prague
SOLO_RPC=http://localhost:7546/
SEED_KEY=0x6c6e6727b40c8d4b616ab0d26af357af09337299f09c66704146e14236972106

ARGS=--sender-funding-txs-gas-price 710000000000
ARGS+=--default-gas-price 710000000000
ARGS+=--sender-fund-refund-gas-limit 1000000
ARGS+=--seed-account-sweep-amount=70000000000000000000000
ARGS+=--eoa-fund-amount-default=8000000000000000000000

FORKS=frontier homestead byzantium constantinople istanbul berlin
# paris
# shanghai
# cancun
# prague
REPORTS=$(patsubst %,tests/%/report.xml,$(FORKS))

.PHONY: all clean pods relay-edit relay-restart

all: $(REPORTS)

clean:
	-rm -v $(REPORTS)

tests/%/report.xml: tests/%/*/test_*.py
	$(UV) run execute remote -rA --verbose --fork=$(FORK) --rpc-endpoint=$(SOLO_RPC) --rpc-seed-key=$(SEED_KEY) --rpc-chain-id 298 --junit-xml=$@ --html=tests/$*/report.html --self-contained-html $(ARGS) tests/$*

junit-html: $(patsubst tests/%/report.xml,tests/%/report.junit-xml.html,$(wildcard tests/*/report.xml))

tests/%/report.junit-xml.html: tests/%/report.xml
	$(JUNIT2HTML) $< $@

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
