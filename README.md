# Metablox Smart Contracts

Metablox is a blockchain-based digital real estate platform where users own, trade, and customize city block NFTs ("Bloxes") on the Polygon network. This repository documents the smart contract architecture and serves as a reference for understanding how the contracts work.

## Contract Architecture

### V1 — Original Contracts (`contracts/v1/`)

The first generation of Metablox contracts used a simple, non-upgradeable design:

| Contract | Description |
|----------|-------------|
| **Metablox.sol** | ERC721 NFT contract with 5-tier pricing and USDT payments |
| **Marketplace.sol** | Peer-to-peer trading with whitelist and commission fees |
| **Memories.sol** | Attach up to 5 memory URIs (photos/media) to each Blox |
| **USDT.sol** | ERC20 token reference (Tether-based) |

### V2 — Singleton City Contracts (`contracts/v2/`)

The second generation introduced the **UUPS proxy pattern** for upgradeability:

| Contract | Description |
|----------|-------------|
| **MetabloxV2WithAccessControl.sol** | One contract per city (San Francisco, Miami, etc.). Uses ERC721Enumerable + ERC721URIStorage + ERC2981 royalties. Supports reserved mint, public batch mint, Chainlink price feeds, grace period phases, landmarks, and role-based access control. |

### Everywhere — Global Contract (`contracts/everywhere/`)

The latest generation consolidates all cities into a single global contract:

| Contract | Description |
|----------|-------------|
| **MetabloxEverywhere.sol** | Global NFT contract supporting all cities worldwide. Uses ERC721Royalty + UUPS. City registration system (Country → State → City), custodial & public batch minting, multi-token payments (USDT, WMATIC, WETH) via Chainlink oracles. |
| **MetabloxMemory.sol** | On-chain memory storage for Blox NFTs |

### Storage & Utilities (`contracts/storage/`)

Shared contracts used by V2 and Everywhere:

| Contract | Description |
|----------|-------------|
| **PropertyTier.sol** | Manages blox pricing across tiers and phases |
| **PropertyLevel.sol** | Attaches ERC3664 attributes (level, XP, generation, points) to bloxes |
| **ERC3664/** | Attribute system for composable on-chain NFT metadata |

### Proxy Pattern Demo (`contracts/proxy-demo/`)

Educational demo illustrating the UUPS proxy pattern:

| Contract | Description |
|----------|-------------|
| **BoxV1.sol** | Simple upgradeable contract with `store()` and `retrieve()` |
| **BoxV2.sol** | Upgraded version adding `increment()` and `lastUpdated()` |

## Proxy Pattern

All V2 and Everywhere contracts use the **UUPS (Universal Upgradeable Proxy Standard)** pattern from OpenZeppelin. This allows upgrading contract logic without changing the contract address or losing stored data.

### How It Works

```
┌────────────┐         ┌─────────────────┐
│   Proxy    │ ──────► │ Implementation  │
│ (Storage)  │         │ (Logic only)    │
│            │         │                 │
│ value = 42 │         │ store()         │
│ owner = 0x │         │ retrieve()      │
└────────────┘         └─────────────────┘
        │
        │  After upgrade:
        │
        │              ┌─────────────────┐
        └────────────► │ Implementation  │
                       │ V2 (New Logic)  │
                       │                 │
                       │ store()         │
                       │ retrieve()      │
                       │ increment() ★   │
                       └─────────────────┘
```

**Key principles:**
- `initialize()` replaces `constructor` — constructors don't work with proxies
- Storage layout must be preserved — only append new state variables, never reorder
- Upgrade events (`Upgraded(address)`) are recorded on-chain and visible on PolygonScan
- Existing data cannot be modified in secret — blockchain transparency is maintained

**Read more:** [Will Proxy Pattern Design become a poison to Smart Contracts?](https://mybaseball52.medium.com/will-proxy-pattern-design-become-a-poison-to-smart-contracts-1b6663913fd1)

## Deployed Contracts (Polygon)

### Mainnet

| City | Contract Address |
|------|-----------------|
| San Francisco | [`0x5761B71B1d7B85a6Fc5F99c06139202891565017`](https://polygonscan.com/address/0x5761B71B1d7B85a6Fc5F99c06139202891565017) |
| Miami | [`0x18d8c8973F4FA685c78b83dE3500c57cD655952F`](https://polygonscan.com/address/0x18d8c8973F4FA685c78b83dE3500c57cD655952F) |
| Singapore | [`0xb170b03C505EF44c06381348081077bfE39b5E93`](https://polygonscan.com/address/0xb170b03C505EF44c06381348081077bfE39b5E93) |
| New York | [`0x43619Ab1D204Eb8384CC37909b0AE5C79D267F2b`](https://polygonscan.com/address/0x43619Ab1D204Eb8384CC37909b0AE5C79D267F2b) |
| Los Angeles | [`0x407315333Eb0cA0A3C9EFf74dA7E6B66310CD3Ef`](https://polygonscan.com/address/0x407315333Eb0cA0A3C9EFf74dA7E6B66310CD3Ef) |
| Global | [`0xB834B596145c69242029c35E849323C8abeB8cFd`](https://polygonscan.com/address/0xB834B596145c69242029c35E849323C8abeB8cFd) |

### Amoy Testnet

| City | Contract Address |
|------|-----------------|
| San Francisco | [`0xf72a2e03C2168D20fCC2a5EE79fd68DbBb642850`](https://amoy.polygonscan.com/address/0xf72a2e03C2168D20fCC2a5EE79fd68DbBb642850) |
| Miami | [`0x2035a2fD8A01B0f1F043b5f498aB06cCa031c819`](https://amoy.polygonscan.com/address/0x2035a2fD8A01B0f1F043b5f498aB06cCa031c819) |
| Singapore | [`0xa6e296d6923c3493114aCf6537c23c9a0E4F9196`](https://amoy.polygonscan.com/address/0xa6e296d6923c3493114aCf6537c23c9a0E4F9196) |
| New York | [`0xE42Afb3310a54c403a9630AEFe48e9B294D97107`](https://amoy.polygonscan.com/address/0xE42Afb3310a54c403a9630AEFe48e9B294D97107) |
| Los Angeles | [`0x73C0f19bbb8Ca4923C8A98510b057a56c84FB7E1`](https://amoy.polygonscan.com/address/0x73C0f19bbb8Ca4923C8A98510b057a56c84FB7E1) |
| Global | [`0x610143800e3154d96F9ffcbb9b8c8aeD731ed13F`](https://amoy.polygonscan.com/address/0x610143800e3154d96F9ffcbb9b8c8aeD731ed13F) |

## Getting Started

### Prerequisites

- Node.js >= 14
- [Truffle](https://trufflesuite.com/) (`npm install -g truffle`)

### Install

```bash
npm install
```

### Compile

```bash
npm run compile
```

### Run the Proxy Demo

```bash
# Start a local blockchain (e.g., Ganache)
ganache-cli

# In another terminal, deploy with the proxy demo migration
truffle migrate --network development
```

The migration script demonstrates:
1. Deploying BoxV1 behind a UUPS proxy
2. Upgrading the proxy to BoxV2
3. Verifying that stored data persists through the upgrade

## Directory Structure

```
contracts/
├── v1/                     # Original non-upgradeable contracts
│   ├── Metablox.sol
│   ├── Marketplace.sol
│   ├── Memories.sol
│   └── USDT.sol
├── v2/                     # Singleton city contract (UUPS proxy)
│   └── MetabloxV2WithAccessControl.sol
├── everywhere/             # Global contract (UUPS proxy)
│   ├── MetabloxEverywhere.sol
│   └── MetabloxMemory.sol
├── storage/                # Shared storage contracts
│   ├── PropertyTier.sol
│   ├── PropertyLevel.sol
│   └── ERC3664/
│       ├── ERC3664.sol
│       ├── IERC3664.sol
│       └── extensions/
│           └── IERC3664Metadata.sol
└── proxy-demo/             # Educational proxy pattern demo
    ├── BoxV1.sol
    └── BoxV2.sol
migrations/                 # Truffle deployment scripts
views/                      # Frontend web interface
```

## License

MIT
