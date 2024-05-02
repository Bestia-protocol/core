<h1 align="center">Bestia Protocol</h1>

<div align="center">

![Solidity](https://img.shields.io/badge/Solidity-0.8.22-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black)

</div>

> Bestia is an innovative stablecoin that acts as a foundational layer for DeFi on Sei.

This repository contains the core smart contracts for Bestia V1.

## How it works

* **Minting**: whitelisted users can lock their sUSDe in a contract on mainnet, that broadcasts a cross-chain message to the USDb contract on Sei minting an equal amount of tokens to them.

* **Burning**: whitelisted users can burn their USDb on Sei and receive an equivalent amount of USDe, as sUSDe, on mainnet.

* **Staking**: users can stake USDb and receive an APY equal to the appreciation in value (USDe denominated) of sUSDe.

## Security

> Audit reports are available in the _audits_ folder.

The codebase comes with full test coverage, including unit, integration and fuzzy tests.

Smart contracts have been tested with the following automated tools:

- [slither](https://github.com/crytic/slither)
- [mythril](https://github.com/Consensys/mythril)
- [halmos](https://github.com/a16z/halmos)
- [olympix](https://www.olympix.ai)

## Licensing

The main license for the Bestia contracts is the Business Source License 1.1 (BUSL-1.1), see LICENSE file to learn more.
The Solidity files licensed under the BUSL-1.1 have appropriate SPDX headers.

## Disclaimer

This application is provided "as is" and "with all faults." Me as developer makes no representations or warranties of
any kind concerning the safety, suitability, lack of viruses, inaccuracies, typographical errors, or other harmful
components of this software. There are inherent dangers in the use of any software, and you are solely responsible for
determining whether this software product is compatible with your equipment and other software installed on your
equipment. You are also solely responsible for the protection of your equipment and backup of your data, and THE
PROVIDER will not be liable for any damages you may suffer in connection with using, modifying, or distributing this
software product.
