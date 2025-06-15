````markdown
# 🛒 NFT Offers Marketplace

**NFT Offers Marketplace** is a minimal smart contract built with Solidity and Foundry that enables users to place ETH bids on NFTs across multiple ERC721 collections. It supports offer placement, cancellation, and owner-side acceptance with fee processing. This contract demonstrates a powerful backend for an NFT market without the need for listings.

> **Note**  
> This contract supports multiple ERC721 collections and enforces security practices such as custom reverts, ETH safety via `call`, and reentrancy protection via OpenZeppelin's `ReentrancyGuard`.

---

## 🔹 Key Features

* ✅ Place ETH offers on any NFT (even if it's not listed).
* ✅ Accept bids as the NFT owner, with fee deduction.
* ✅ Cancel your own offers and receive refund.
* ✅ Supports **multiple ERC721 collections**.
* ✅ Configurable **marketplace fee** and **fee recipient** by the owner.
* ✅ Protected against **reentrancy** and **ETH transfer failures**.

---

## 📄 Deployed Contract

| 🔧 Item                    | 📋 Description                                |
| ------------------------- | --------------------------------------------- |
| **Contract Name**         | `Marketplace`                                 |
| **Deployed Network**      | Local / Not Deployed                          |
| **Constructor Parameters**| `uint256 feePercent`, `address feeRecipient`  |

---

## 🚀 How to Use Locally

### 1️⃣ Clone and Set Up

```bash
git clone https://github.com/yourusername/nft-offers-marketplace.git
cd nft-offers-marketplace
````

### 2️⃣ Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 3️⃣ Run Tests

```bash
forge test -vvvv
```

---

## 🧠 Project Structure

```
nft-offers-marketplace/
├── lib/                           # OpenZeppelin and external libraries
├── script/                        # Deployment scripts (optional)
├── src/
│   └── Marketplace.sol            # Main marketplace smart contract
├── test/
│   ├── Marketplace.t.sol          # Complete test suite using Foundry
│   └── mocks/                     # Custom test helpers (optional)
├── foundry.toml                   # Foundry configuration
└── README.md                      # Project documentation
```

---

## 🔍 Contract Summary

### Functions

| Function                               | Description                                           |
| -------------------------------------- | ----------------------------------------------------- |
| `makeBid(address, uint256)`            | Place an ETH bid on a specific NFT                    |
| `cancelBid(address, uint256)`          | Cancel an existing bid and refund ETH                 |
| `acceptBid(address, uint256, address)` | Owner accepts the bid, transfers NFT and receives ETH |
| `updateFeePercent(uint256)`            | Owner can update marketplace fee                      |
| `updateFeeRecipient(address)`          | Owner can update fee recipient wallet                 |

---

## 🛠️ Potential Improvements

* 🔁 Add listing functionality (NFTs offered for fixed prices).
* 🔐 Add Merkle Tree whitelist for exclusive offers.
* 📈 Track bids with historical logs or off-chain indexing.
* ⚙️ Add time-based expiration for bids.

---

## 🧪 Tests

The project includes full Foundry tests covering all core logic:

* ✅ Constructor validation
* ✅ Fee updates and permissions
* ✅ `makeBid()` logic, events, and restrictions
* ✅ `cancelBid()` with ETH refund
* ✅ `acceptBid()` including ETH/fee handling and NFT transfers
* ✅ Reverts on non-owner actions, missing approvals, and failing ETH sends

---

## 📊 Test Coverage

The project achieves **100% test coverage** across all paths:

| File                     | % Lines  | % Statements | % Branches | % Functions |
| ------------------------ | -------- | ------------ | ---------- | ----------- |
| `src/Marketplace.sol`    | 100.00%  | 100.00%      | 100.00%    | 100.00%     |
| `test/Marketplace.t.sol` | 100.00%  | 100.00%      | 100.00%    | 100.00%     |
| **Total**                | **100%** | **100%**     | **100%**   | **100%**    |

> Generated using [`forge coverage`](https://book.getfoundry.sh/forge/coverage).

---

## 📜 License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

### 🚀 NFT Offers Marketplace: Flexible bidding infrastructure for ERC721 assets.
