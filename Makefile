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
JUNIT2HTML=~/.local/bin/junit2html
HTML_MERGER=~/.local/bin/pytest_html_merger

FORK=Cancun
SOLO_RPC=http://localhost:7546/
SEED_KEY=0x6c6e6727b40c8d4b616ab0d26af357af09337299f09c66704146e14236972106

ARGS=--sender-funding-txs-gas-price 710000000000
ARGS+=--default-gas-price 710000000000
ARGS+=--sender-fund-refund-gas-limit 1000000
ARGS+=--seed-account-sweep-amount=70000000000000000000000
ARGS+=--eoa-fund-amount-default=8000000000000000000000

# berlin
# paris
# cancun
# FORKS=frontier homestead byzantium constantinople istanbul shanghai cancun
FORKS=byzantium constantinople
XML_HTMLS=$(patsubst %,tests/%/report-junit.xml.html,$(FORKS))

.PHONY: all clean pods relay-edit relay-restart

TEST_PYS=$(wildcard tests/*/*/test_*.py)
EIPS_REPORTS=$(patsubst %/,%.html,$(dir $(TEST_PYS)))

XML_HTMLS=$(patsubst %,%report-junit.xml.html,$(EIPS))

all: report.html
# 	@echo $(EIPS_REPORTS)

report.html: $(patsubst %,tests/report-%.html,$(FORKS))
	@echo $? "-->>" $@
	$(HTML_MERGER) -i tests/ -o $@

P:=%

# tests/report-%.html: $(patsubst $(P),$(P)-eip.html,tests/%/eip*)
# 	@echo $? "-->>" $@

.SECONDEXPANSION:

# tests/report-%.html: $$(patsubst $$(P),$$(P)-eip.html,tests/%/eip*)
# 	@echo $? "-->>" $@

tests/report-%.html: $$(patsubst $$(P)/,$$(P)-eip.html,$$(dir $$(wildcard tests/%/*/test_*.py)))
# tests/report-%.html: $$(addsuffix .asdf,$$(dir $$(wildcard tests/%/*/test_*.py)) )
# tests/report-%.html: $(filter tests/%/*.html,$(EIPS_REPORTS))
	@echo $? "-->>" $@ $*
	$(HTML_MERGER) -i tests/$* -o $@

# tests/%/report-junit.xml: tests/%/test_*.py

.PRECIOUS: tests/%-eip.html tests/%.py.html

tests/%-eip.html: $$(patsubst $$(P).py,$$(P).py.html,$$(wildcard tests/%/test_*.py))
	@echo merge eip $? $@ $*
	$(HTML_MERGER) -i tests/$* -o $@

# tests/%.html: tests/%/test_*.html


tests/%.py.html: tests/%.py
	$(UV) run execute remote -rA --verbose --suppress-no-test-exit-code --fork=$(FORK) --rpc-endpoint=$(SOLO_RPC) --rpc-seed-key=$(SEED_KEY) --rpc-chain-id 298 --html=$@ --self-contained-html $(ARGS) $<

clean:
	-rm -v $(XML_HTMLS) tests/*/report.html

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
