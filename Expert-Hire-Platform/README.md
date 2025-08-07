# FreelanceConnect: Decentralized Talent Marketplace

A blockchain-based platform built on Stacks that connects skilled freelancers with clients through secure, transparent smart contracts. Features automated escrow payments, on-chain reputation tracking, milestone-based project management, and decentralized dispute resolution.

## Features

### Core Functionality
- **Automated Escrow System**: Secure payment handling with funds locked until work completion
- **Reputation Tracking**: On-chain performance ratings for both providers and clients
- **Milestone Management**: Break projects into manageable phases with milestone-based payments
- **Dispute Resolution**: Decentralized arbitration system with admin oversight
- **Professional Verification**: Admin-verified credential system for providers

### Security Features
- Cryptographic verification of all transactions
- Transparent state management on-chain
- Access control for all critical functions
- Validation of wallet addresses and parameters

## Architecture

### Data Structures

#### Work Agreements
- Service provider and client wallets
- Project timelines and deadlines
- Compensation amounts and escrow status
- Agreement status tracking
- Project completion timestamps

#### User Profiles
- **Provider Profiles**: Performance ratings, project history, earnings, verification status
- **Client Profiles**: Project history, spending, trustworthiness scores, payment reliability

#### Dispute System
- Dispute tracking with timestamps
- Arbitration deadlines
- Admin decision recording

#### Milestone System
- Milestone-based project breakdown
- Individual milestone compensation
- Completion and approval tracking

## Financial Configuration

- **Minimum Project Value**: 1 STX (configurable by admin)
- **Platform Commission**: 2.5% (configurable up to 10%)
- **Dispute Resolution Window**: ~1 week (1008 blocks)

## Core Functions

### Work Agreement Lifecycle

#### `establish-professional-work-agreement`
Creates a new work agreement with automatic escrow
```clarity
(establish-professional-work-agreement 
    agreement-id 
    provider-wallet 
    start-timestamp 
    deadline 
    compensation-amount)
```

#### `provider-accepts-work-agreement`
Provider accepts the work agreement
```clarity
(provider-accepts-work-agreement agreement-id)
```

#### `submit-completed-work-for-evaluation`
Provider submits completed work for client review
```clarity
(submit-completed-work-for-evaluation agreement-id)
```

#### `approve-deliverables-and-release-payment`
Client approves work and releases escrowed payment
```clarity
(approve-deliverables-and-release-payment agreement-id)
```

#### `request-work-revisions`
Client requests revisions to submitted work
```clarity
(request-work-revisions agreement-id)
```

### Dispute Resolution

#### `initiate-work-agreement-dispute`
Either party can initiate a dispute
```clarity
(initiate-work-agreement-dispute agreement-id)
```

#### `resolve-disputed-work-agreement`
Admin resolves disputes with payment decisions
```clarity
(resolve-disputed-work-agreement agreement-id award-to-provider)
```

### Reputation System

#### `submit-provider-performance-rating`
Submit ratings for completed work (1-5 scale)
```clarity
(submit-provider-performance-rating provider-wallet rating-score)
```

#### `verify-provider-professional-credentials`
Admin verification of provider credentials
```clarity
(verify-provider-professional-credentials provider-wallet)
```

### Milestone Management

#### `establish-project-milestone`
Create project milestones with individual payments
```clarity
(establish-project-milestone 
    agreement-id 
    milestone-number 
    compensation-amount 
    deadline)
```

#### `complete-project-milestone`
Mark milestone as completed by provider
```clarity
(complete-project-milestone agreement-id milestone-number)
```

#### `approve-completed-milestone`
Client approval of completed milestone
```clarity
(approve-completed-milestone agreement-id milestone-number)
```

## Query Functions

### Agreement Information
- `retrieve-work-agreement-details(agreement-id)`: Get complete agreement details
- `retrieve-dispute-information(agreement-id)`: Get dispute status and details

### Profile Information
- `retrieve-provider-professional-profile(wallet)`: Get provider metrics and ratings
- `retrieve-client-organizational-profile(wallet)`: Get client history and scores

### Platform Statistics
- `retrieve-comprehensive-platform-statistics()`: Get platform-wide metrics
- `get-marketplace-administrator-wallet()`: Get current admin wallet

### Milestone Information
- `retrieve-milestone-information(agreement-id, milestone-number)`: Get milestone details
- `get-performance-rating(provider-wallet, block-height)`: Get specific rating details

## Access Control

### Admin Functions (Marketplace Administrator Only)
- `transfer-marketplace-ownership(new-admin-wallet)`
- `modify-platform-operational-status(status)`
- `adjust-marketplace-commission-rate(new-rate)`
- `set-minimum-project-threshold(new-minimum)`
- `verify-provider-professional-credentials(provider-wallet)`
- `resolve-disputed-work-agreement(agreement-id, award-decision)`

### User Functions
- Agreement lifecycle management
- Milestone creation and management
- Rating submission
- Dispute initiation

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | ERR-ACCESS-DENIED | Unauthorized access attempt |
| 101 | ERR-WORK-AGREEMENT-EXISTS | Agreement ID already exists |
| 102 | ERR-WORK-AGREEMENT-NOT-FOUND | Agreement not found |
| 103 | ERR-INVALID-STATUS-CHANGE | Invalid status transition |
| 104 | ERR-PAYMENT-AMOUNT-TOO-LOW | Payment below minimum threshold |
| 105 | ERR-INVALID-WALLET-ADDRESS | Invalid wallet format |
| 106 | ERR-INVALID-PARAMETERS | Invalid function parameters |
| 107 | ERR-PLATFORM-UNDER-MAINTENANCE | Platform temporarily disabled |
| 108 | ERR-INVALID-PROJECT-TIMELINE | Invalid project dates |
| 109 | ERR-RATING-VALUE-OUT-OF-BOUNDS | Rating not between 1-5 |
| 110 | ERR-SELF-CONTRACTING-NOT-ALLOWED | Cannot contract with yourself |
| 111 | ERR-DISPUTE-RESOLUTION-EXPIRED | Dispute resolution deadline passed |
| 112 | ERR-PAYMENT-ALREADY-RELEASED | Payment already processed |
| 113 | ERR-INSUFFICIENT-FUNDS | Insufficient STX balance |

## Getting Started

### Prerequisites
- Stacks blockchain access
- STX tokens for transactions and escrow
- Clarity-compatible wallet

### Deployment
1. Deploy the contract to Stacks blockchain
2. Set initial configuration parameters
3. Fund the contract for escrow operations

### Usage Flow
1. **Client**: Create work agreement with escrow
2. **Provider**: Accept agreement to start work
3. **Provider**: Submit completed work
4. **Client**: Review and approve/request revisions
5. **System**: Release payment upon approval
6. **Both**: Submit ratings for reputation building

## Security Considerations

- All funds are held in secure escrow until work completion
- Multi-signature admin functions for platform governance
- Comprehensive input validation and access controls
- Transparent on-chain dispute resolution
- Protected against self-contracting and double payments