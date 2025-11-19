# ComicCoin - Micropayment Service for Webcomic Artists

A decentralized micropayment platform built on the Stacks (STX) blockchain using Clarity smart contracts. ComicCoin enables webcomic artists and illustrators to monetize their work directly, allowing readers to purchase episodes and support creators with minimal friction.

## Overview

ComicCoin is a fungible token-based ecosystem that connects artists with readers. Artists can register, create comic series with custom pricing, and earn ComicCoins directly from episode purchases. The platform takes a small fee (default 2%) to maintain the service while ensuring artists receive fair compensation.

## Key Features

- **Artist Registration**: Easy onboarding for webcomic creators with profile management
- **Series Creation**: Publish comic series with customizable episode pricing
- **Direct Micropayments**: Readers purchase individual episodes instantly
- **Automatic Payouts**: Artists earn ComicCoins automatically upon purchase
- **Purchase History**: Prevents duplicate purchases and tracks reader engagement
- **Fee Management**: Transparent platform fee system (configurable by admin)
- **Token Economy**: Mint, burn, and transfer ComicCoins seamlessly

## Smart Contract Architecture

### Core Components

#### Fungible Token
- **Token Name**: comic-coin
- **Divisibility**: Standard STX fungible token
- **Supply**: Controlled via mint/burn functions

#### Data Structures

**Artist Profiles**
- Artist principal address
- Display name (100 characters)
- Bio/description (500 characters)
- Total earnings tracker
- Active status

**Comic Series**
- Unique series ID
- Artist principal
- Title and description
- Price per episode (in microcoins)
- Total sales count
- Creation timestamp

**Episode Purchases**
- Reader address
- Series ID
- Episode number
- Purchase timestamp
- Amount paid

### Global Variables
- `contract-owner`: Administrative account
- `platform-fee`: Current fee percentage (default 2%)
- `total-earnings`: Cumulative platform fees collected
- `next-series-id`: Counter for new series

## How It Works

### For Artists

1. **Register Profile**
   ```clarity
   (register-artist "Comic Name" "Short bio describing your work")
   ```

2. **Create a Series**
   ```clarity
   (create-series "My First Comic" "An epic adventure" u100)
   ```
   This creates a series where each episode costs 100 microcoins.

3. **Update Pricing** (if needed)
   ```clarity
   (update-series-price series-id u150)
   ```

4. **Track Earnings**
   - Earnings automatically update upon each purchase
   - View profile to see total earned
   - Artists receive 98% of purchase price (2% platform fee)

### For Readers

1. **Purchase an Episode**
   ```clarity
   (purchase-episode series-id episode-number amount)
   ```
   - Must provide amount equal to or greater than episode price
   - Payment transfers directly to artist
   - Purchase is recorded and prevents re-purchasing same episode

2. **Check Ownership**
   ```clarity
   (has-purchased reader-address series-id episode-num)
   ```
   - Returns true if episode was previously purchased
   - Enables access control in front-end applications

## Public Functions

### Artist Management

**`register-artist`**
- **Parameters**: name (string-ascii 100), description (string-ascii 500)
- **Returns**: Boolean success
- **Description**: Create artist profile on the platform

**`update-artist-profile`**
- **Parameters**: name (string-ascii 100), description (string-ascii 500)
- **Returns**: Boolean success
- **Description**: Update existing artist profile information

### Series Management

**`create-series`**
- **Parameters**: title (string-ascii 100), description (string-ascii 500), price-per-episode (uint)
- **Returns**: Series ID on success
- **Description**: Launch new comic series with specified episode price
- **Requirements**: Caller must be registered artist

**`update-series-price`**
- **Parameters**: series-id (uint), new-price (uint)
- **Returns**: Boolean success
- **Description**: Adjust episode pricing for existing series
- **Requirements**: Caller must be the series creator

### Micropayments

**`purchase-episode`**
- **Parameters**: series-id (uint), episode-num (uint), amount (uint)
- **Returns**: Boolean success
- **Description**: Purchase episode and transfer payment to artist
- **Logic**: 
  - Validates series exists and is active
  - Prevents duplicate purchases
  - Calculates and splits fees automatically
  - Updates artist earnings and series sales count

### Token Management

**`mint`**
- **Parameters**: amount (uint), recipient (principal)
- **Returns**: Boolean success
- **Description**: Create new ComicCoins
- **Requirements**: Admin only

**`burn`**
- **Parameters**: amount (uint)
- **Returns**: Boolean success
- **Description**: Destroy ComicCoins from caller's balance
- **Requirements**: Caller must have sufficient balance

**`set-platform-fee`**
- **Parameters**: new-fee (uint)
- **Returns**: Boolean success
- **Description**: Update platform fee percentage
- **Requirements**: Admin only
- **Constraints**: Fee must be 0-100 (representing 0-100%)

## Read-Only Functions

**`get-artist`**
- Returns complete artist profile or null if not found

**`get-series`**
- Returns comic series details including sales count and pricing

**`has-purchased`**
- Returns true/false for episode ownership check

**`get-balance`**
- Returns ComicCoin balance for any principal

**`get-total-supply`**
- Returns total ComicCoins in circulation

**`get-contract-info`**
- Returns contract metadata (owner, fee, earnings, series count)

## Error Codes

| Code | Error | Meaning |
|------|-------|---------|
| u1 | ERR-NOT-OWNER | Caller is not contract administrator |
| u2 | ERR-NOT-ARTIST | Caller is not a registered artist |
| u3 | ERR-SERIES-NOT-FOUND | Series ID doesn't exist |
| u4 | ERR-INSUFFICIENT-BALANCE | Insufficient funds for transaction |
| u5 | ERR-ARTIST-INACTIVE | Artist account is inactive |
| u6 | ERR-ALREADY-PURCHASED | Episode already purchased by reader |
| u7 | ERR-INVALID-PRICE | Price is invalid (e.g., zero) |
| u8 | ERR-UNAUTHORIZED | Unauthorized action (e.g., modifying another's series) |

## Fee Structure

- **Platform Fee**: 2% (default, configurable)
- **Artist Payout**: 98% of purchase price
- **Example**: 100 microcoins purchase = 2 microcoins fee, 98 microcoins to artist

## Security Considerations

- All transactions require proper authorization
- Artist-only actions validated via principal matching
- Duplicate purchase prevention protects readers
- Invalid pricing checks prevent exploits
- Admin functions restricted to contract owner
- Error handling for all edge cases

## Deployment

### Prerequisites
- Stacks blockchain node or testnet access
- Clarity contract deployment tools
- STX tokens for deployment fees

### Deploy Command
```bash
stx deploy ./contracts/ComicCoin.clar
```

### Configuration
After deployment, the contract owner should:
1. Mint initial ComicCoin supply
2. Adjust platform fee if needed
3. Distribute initial coins to known artists/readers

## Example Usage Flow

### Scenario: New Artist Launches Comic

```clarity
;; Step 1: Artist registers
(register-artist "Luna's Adventures" "Epic fantasy webcomic")
;; Returns: true

;; Step 2: Artist creates series
(create-series "Season 1" "The journey begins..." u50)
;; Returns: series-id 0

;; Step 3: Reader purchases episode 1
(purchase-episode u0 u1 u50)
;; Returns: true
;; Artist receives 49 microcoins, platform gets 1

;; Step 4: Check if purchased
(has-purchased reader-address u0 u1)
;; Returns: true

;; Step 5: Reader attempts duplicate purchase
(purchase-episode u0 u1 u50)
;; Returns: ERR-ALREADY-PURCHASED (error u6)
```

## Future Enhancements

- Batch episode purchases
- Subscription-based series access
- Reader tipping mechanism
- Revenue sharing partnerships
- Comic series collections/bundles
- Artist collaboration splits
- Staking rewards for long-term holders
- Governance token integration

## License

This smart contract is provided as-is for the Stacks blockchain ecosystem.

## Support

For questions or issues, please refer to Stacks documentation at https://docs.stacks.co/ and Clarity language reference at https://docs.stacks.co/clarity/