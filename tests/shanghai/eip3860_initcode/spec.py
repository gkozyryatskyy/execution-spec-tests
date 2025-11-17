"""Defines EIP-3860 specification constants and functions."""

from dataclasses import dataclass


@dataclass(frozen=True)
class ReferenceSpec:
    """Defines the reference spec version and git path."""

    git_path: str
    version: str


ref_spec_3860 = ReferenceSpec("EIPS/eip-3860.md", "9ee005834d488e381455cf86a56c741a2e854a17")


@dataclass(frozen=True)
class Spec:
    """
    Define parameters from the EIP-3860 specifications.

    These are the parameters defined at
    https://eips.ethereum.org/EIPS/eip-3860#parameters.
    """

    # TODO Glib: seems like Hedera has no INITCODE limit check.
    #  Hedera has just Jumbo tx payload check = 131072
    #  details https://swirldslabs.slack.com/archives/C09B3UPEMKM/p1756384889485429
    #   - https://github.com/hiero-ledger/hiero-consensus-node/issues/20872
    # JUMBO_MAX_PAYLOAD_SIZE = 131072

    # TODO Glib: for contract create: initcode limit -> jumbo tx payload limit
    #  - https://github.com/hiero-ledger/hiero-consensus-node/issues/20872
    MAX_INITCODE_SIZE = 49152
    # MAX_INITCODE_SIZE = JUMBO_MAX_PAYLOAD_SIZE

    INITCODE_WORD_COST = 2
